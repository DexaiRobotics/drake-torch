

#include <memory>
#include <cmath>
#include <cstdlib>
#include <random>

#include <gflags/gflags.h>

#include "drake/common/drake_assert.h"
#include "drake/common/find_resource.h"
#include "drake/common/text_logging_gflags.h"
#include "drake/geometry/geometry_visualization.h"
#include "drake/geometry/scene_graph.h"
#include "drake/lcm/drake_lcm.h"
#include "drake/multibody/benchmarks/acrobot/make_acrobot_plant.h"
#include "drake/multibody/parsing/parser.h"
#include "drake/multibody/tree/revolute_joint.h"
#include "drake/multibody/tree/prismatic_joint.h"
#include "drake/multibody/tree/uniform_gravity_field_element.h"
#include "drake/systems/analysis/simulator.h"
#include "drake/systems/controllers/linear_quadratic_regulator.h"
#include "drake/systems/framework/diagram_builder.h"
#include "drake/systems/primitives/affine_system.h"
#include "drake/systems/rendering/pose_bundle_to_draw_message.h"
#include "drake/systems/primitives/signal_logger.h"

// #include "rl_memory.h"
#include "rl_controller.h"
#include "visdom.h"

namespace drake {

using geometry::SceneGraph;
using lcm::DrakeLcm;
using multibody::benchmarks::acrobot::AcrobotParameters;
using multibody::benchmarks::acrobot::MakeAcrobotPlant;
using multibody::MultibodyPlant;
using multibody::Parser;
using multibody::JointActuator;
using multibody::RevoluteJoint;
using drake::multibody::PrismaticJoint;
using multibody::UniformGravityFieldElement;
using systems::Context;
using systems::Diagram;

namespace examples {
namespace multibody {
namespace cart_pole {
namespace {

DEFINE_double(target_realtime_rate, 100.0,
            "Desired rate relative to real time.  See documentation for "
            "Simulator::set_target_realtime_rate() for details.");

DEFINE_double(simulation_time, 10.0,
              "Desired duration of the simulation in seconds.");

DEFINE_bool(time_stepping, true, "If 'true', the plant is modeled as a "
    "discrete system with periodic updates. "
    "If 'false', the plant is modeled as a continuous system.");

int do_main() {
    VisdomInterface viz; 
    const double time_step = FLAGS_time_stepping ? 1.0e-2 : 0.0;
    Options options;
    std::random_device rd;
    std::mt19937 e2(rd());
    std::uniform_real_distribution<> dist(0, 1000);
    double sample = dist(e2); 
    torch::manual_seed(int(sample));
    VectorX<float> goal_state = VectorX<float>::Zero(4);
    goal_state << M_PI, 0, 0, 0; 

    DQN dqn(options); 

    ReplayMemory memory(200000); 

    systems::DiagramBuilder<double> builder;

    SceneGraph<double>& scene_graph = *builder.AddSystem<SceneGraph>();
    scene_graph.set_name("scene_graph");

    // Make and add the cart_pole model.
    const std::string relative_name =
        "drake/examples/multibody/cart_pole/cart_pole.sdf";
    const std::string full_name = FindResourceOrThrow(relative_name);
    MultibodyPlant<double>& cart_pole =
        *builder.AddSystem<MultibodyPlant>(time_step);

    Parser parser(&cart_pole, &scene_graph);
    parser.AddModelFromFile(full_name);

    // Add gravity to the model.
    cart_pole.AddForceElement<UniformGravityFieldElement>(
        -9.81 * Vector3<double>::UnitZ());

    // We are done defining the model.
    cart_pole.Finalize();

    DRAKE_DEMAND(cart_pole.num_actuators() == 1);
    DRAKE_DEMAND(cart_pole.num_actuated_dofs() == 1);

    // Get joints so that we can set initial conditions.
    PrismaticJoint<double>& cart_slider =
        cart_pole.GetMutableJointByName<PrismaticJoint>("CartSlider");
    RevoluteJoint<double>& pole_pin =
        cart_pole.GetMutableJointByName<RevoluteJoint>("PolePin");

    // Drake's parser will default the name of the actuator to match the name of
    // the joint it actuates.
    const JointActuator<double>& actuator =
        cart_pole.GetJointActuatorByName("CartSlider");
    DRAKE_DEMAND(actuator.joint().name() == "CartSlider");

    auto hacked_controller = builder.AddSystem(
        std::make_unique<systems::controllers::FixedOutputController>(4, 1, VectorX<double>::Zero(1) ));
    builder.Connect(cart_pole.get_continuous_state_output_port(),
                    hacked_controller->get_input_port(0));
    builder.Connect(hacked_controller->get_output_port(0),
                    cart_pole.get_actuation_input_port());

    // Sanity check on the availability of the optional source id before using it.
    DRAKE_DEMAND(!!cart_pole.get_source_id());

    builder.Connect(
        cart_pole.get_geometry_poses_output_port(),
        scene_graph.get_source_pose_port(cart_pole.get_source_id().value()));

    geometry::ConnectDrakeVisualizer(&builder, scene_graph);

    // Log the true state and the control output.
    auto x_logger = systems::LogOutput(cart_pole.get_continuous_state_output_port(), &builder);
    x_logger->set_name("x_logger");

    auto diagram = builder.Build();

    // Create a context for this system:
    std::unique_ptr<systems::Context<double>> diagram_context =
            diagram->CreateDefaultContext();
    diagram->SetDefaultContext(diagram_context.get());
    systems::Context<double>& cart_pole_context =
            diagram->GetMutableSubsystemContext(cart_pole, diagram_context.get());
    // Set initial state.
    cart_slider.set_translation(&cart_pole_context, 0.0);

    systems::Simulator<double> simulator(*diagram);
    simulator.set_target_realtime_rate(FLAGS_target_realtime_rate);

    // Setup distribution for random initial conditions.
    RandomGenerator generator;
    std::normal_distribution<symbolic::Expression> gaussian;
    pole_pin.set_random_angle_distribution(M_PI + 0.1*gaussian(generator));  

    x_logger->set_publish_period(time_step);
    simulator.set_publish_every_time_step(false);

    int steps_done = 0; 
    std::vector<double> epoch_list;
    std::vector<double> reward_list; 
    for (int epoch = 0; epoch < options.epochs; epoch++) {
        std::uniform_real_distribution<> initial_position(-0.2, 0.2);
        double sample_initial_position = initial_position(e2); 
        double sample_initial_velocity = initial_position(e2); 
        cart_slider.set_translation(&cart_pole_context, sample_initial_position);
        cart_slider.set_translation_rate(&cart_pole_context, sample_initial_velocity);
        simulator.get_mutable_context().set_time(0.0);
        simulator.get_system().SetRandomContext(&simulator.get_mutable_context(),
                                                    &generator);
        x_logger->reset();
        
        simulator.Initialize();
        int num_steps = int(FLAGS_simulation_time / time_step);
        float loss = 0; 
        float reward = 0; 
        std::pair<float,float> dueling_q; 
        for(int t=0; t<num_steps; t++){
            
            int last_element_x = x_logger->data().cols() - 1; 
            
            if(last_element_x < 0){
                std::cout << "Yeah, this happened!" << std::endl; 
                simulator.StepTo(t*time_step);
                continue; 
            }

            Transition trans;
            VectorX<double> state = x_logger->data().col(last_element_x);
            // hacked_controller->SetOutput(ctrl_inp);
            trans.state = state.cast<float>();
            // trans.state(1) -= M_PI; 
            trans.action = int64_t(dqn.SelectAction(trans.state, steps_done, t));
            auto action_vector = dqn.ActionIntToVector(trans.action); 
            hacked_controller->SetOutput(action_vector);

            // step
            simulator.StepTo(t*time_step);
            last_element_x = x_logger->data().cols() - 1; 
            VectorX<double> next_state = x_logger->data().col(last_element_x);
            trans.next_state = next_state.cast <float> ();
            // std::cout << "next state:" << trans.next_state << std::endl; 
            if (fabs(M_PI - trans.next_state(1)) > M_PI/8.0){
                trans.done = true;
                trans.reward = 0.0; //-M_PI;
            } else if (fabs(trans.next_state(0)) > 1.5){
                // std::cout << "done!\n";
                trans.done = true;
                trans.reward = 0.0; //-M_PI;
            } else {
                trans.done = false; 
                trans.reward = 1.0; //(M_PI - trans.state(1)) - (M_PI - trans.next_state(1));
            }
            
            if(t % 1 == 0 || trans.done){
                memory.Push(trans); 
                reward += trans.reward;
                dueling_q = dqn.Optimize(memory); 
                steps_done++;
            }
            
            if (trans.done){
                break;
            }
        }
        reward_list.push_back(reward);
        epoch_list.push_back(epoch);
        // viz.Line(epoch_list, reward_list);
        if(epoch % options.log_interval == 0){
            dqn.UpdateTargetNet(); 
        }
        std::cout << "q policy: " << dueling_q.first << " vs. q target: " << dueling_q.second << std::endl; 
        std::cout << "sum reward: " << reward << std::endl; 
        std::cout << "memory size: " << memory.size() << std::endl; 
        // simulator.StepTo(FLAGS_simulation_time);

        // std::cout << x_logger->sample_times().size() << std::endl; 
        // std::cout << x_logger->data().rows() << std::endl; 
        // std::cout << x_logger->data().cols() << std::endl; 
    }

    // std::vector<std::tuple<double,VectorX<double>,double>> result; 
    // int num_samples = x_logger->sample_times().size();
    // for(int i=0; i<num_samples; i++){
    //     double t = x_logger->sample_times()(i);
    //     VectorX<double> vec = x_logger->data().col(i); 
    //     auto tuple = std::make_tuple(t, vec, control);
    //     result.push_back(tuple);
    // }

}
}  // namespace
}  // namespace cart_pole
}  // namespace multibody
}  // namespace examples
}  // namespace drake

int main(int argc, char* argv[]) {
  gflags::SetUsageMessage(
      "A simple cart_pole demo using Drake's MultibodyPlant with "
      "LQR stabilization. "
      "Launch drake-visualizer before running this example.");
  gflags::ParseCommandLineFlags(&argc, &argv, true);
  drake::logging::HandleSpdlogGflags();
  return drake::examples::multibody::cart_pole::do_main();
}
