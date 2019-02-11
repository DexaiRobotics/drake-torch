#include "acrobot_plant.h"
#include "drake/multibody/benchmarks/acrobot/make_acrobot_plant.h"
// #include "rl_acrobot_model.h"
// #include "rl_memory.h"
#include "rl_controller.h"
#include "visdom.h"

namespace drake {
using geometry::SceneGraph;
using geometry::SourceId;
using lcm::DrakeLcm;
using multibody::benchmarks::acrobot::AcrobotParameters;
using multibody::benchmarks::acrobot::MakeAcrobotPlant;
using multibody::MultibodyPlant;
using multibody::RevoluteJoint;
namespace examples {
namespace multibody {
namespace acrobot {
namespace {

DEFINE_double(target_realtime_rate, 100.0,
            "Desired rate relative to real time.  See documentation for "
            "Simulator::set_target_realtime_rate() for details.");

DEFINE_double(simulation_time, 30.0,
              "Desired duration of the simulation in seconds.");

DEFINE_bool(time_stepping, true, "If 'true', the plant is modeled as a "
    "discrete system with periodic updates. "
    "If 'false', the plant is modeled as a continuous system.");

int do_main() {
    VisdomInterface viz; 
    const double time_step = FLAGS_time_stepping ? 1.0e-2 : 0.0;
    Options options(false); //no_cuda = false
    torch::manual_seed(options.seed);
    VectorX<float> goal_state = VectorX<float>::Zero(4);
    goal_state << M_PI, 0, 0, 0; 

    DQN dqn(options); 

    ReplayMemory memory(200000); 

    systems::DiagramBuilder<double> builder;

    SceneGraph<double>& scene_graph = *builder.AddSystem<SceneGraph>();
    scene_graph.set_name("scene_graph");
    // Make and add the acrobot model.
    // const AcrobotParameters acrobot_parameters;
    // MultibodyPlant<double>& acrobot = *builder.AddSystem(MakeAcrobotPlant(
    // acrobot_parameters, true /* Finalize the plant */, &scene_graph)); 
    
    const std::string relative_name =
        "drake/multibody/benchmarks/acrobot/acrobot.sdf";
    const std::string full_name = FindResourceOrThrow(relative_name);
    MultibodyPlant<double>& acrobot =
        *builder.AddSystem<MultibodyPlant>(time_step);

    Parser parser(&acrobot, &scene_graph);
    parser.AddModelFromFile(full_name);

    // Add gravity to the model.
    acrobot.AddForceElement<UniformGravityFieldElement>(
        -9.81 * Vector3<double>::UnitZ());

    // We are done defining the model.
    acrobot.Finalize();

    DRAKE_DEMAND(acrobot.num_actuators() == 1);
    DRAKE_DEMAND(acrobot.num_actuated_dofs() == 1);

    RevoluteJoint<double>& shoulder =
        acrobot.GetMutableJointByName<RevoluteJoint>("ShoulderJoint");
    RevoluteJoint<double>& elbow =
        acrobot.GetMutableJointByName<RevoluteJoint>("ElbowJoint");

    // Drake's parser will default the name of the actuator to match the name of
    // the joint it actuates.
    const JointActuator<double>& actuator =
        acrobot.GetJointActuatorByName("ElbowJoint");
    DRAKE_DEMAND(actuator.joint().name() == "ElbowJoint");

    // For this example the controller's model of the plant exactly matches the
    // plant to be controlled (in reality there would always be a mismatch).
    
    auto controller = builder.AddSystem(
        MakeBalancingLQRController(relative_name));
    controller->set_name("controller");
    builder.Connect(acrobot.get_continuous_state_output_port(),
                    controller->get_input_port());
    // builder.Connect(controller->get_output_port(),
    //                 acrobot.get_actuation_input_port());

    auto hacked_controller = builder.AddSystem(
        std::make_unique<systems::controllers::FixedOutputController>(4, 1, VectorX<double>::Zero(1) ));
    builder.Connect(acrobot.get_continuous_state_output_port(),
                    hacked_controller->get_input_port(0));
    builder.Connect(hacked_controller->get_output_port(0),
                    acrobot.get_actuation_input_port());

    // Sanity check on the availability of the optional source id before using it.
    DRAKE_DEMAND(!!acrobot.get_source_id());

    builder.Connect(
        acrobot.get_geometry_poses_output_port(),
        scene_graph.get_source_pose_port(acrobot.get_source_id().value()));

    geometry::ConnectDrakeVisualizer(&builder, scene_graph);

    // Log the true state and the control output.
    auto x_logger = systems::LogOutput(acrobot.get_continuous_state_output_port(), &builder);
    x_logger->set_name("x_logger");
    auto control_logger = systems::LogOutput(controller->get_output_port(), &builder);
    control_logger->set_name("control_logger");

    auto diagram = builder.Build();
    // Create a context for this system:
    std::unique_ptr<systems::Context<double>> diagram_context =
            diagram->CreateDefaultContext();

    systems::Simulator<double> simulator(*diagram);
    simulator.set_target_realtime_rate(FLAGS_target_realtime_rate);

    // Setup distribution for random initial conditions.
    RandomGenerator generator;
    std::normal_distribution<symbolic::Expression> gaussian;
    shoulder.set_random_angle_distribution(M_PI + 0.01*gaussian(generator)); // 
    elbow.set_random_angle_distribution(0.01*gaussian(generator));

    systems::Context<double>& acrobot_context =
            diagram->GetMutableSubsystemContext(acrobot, diagram_context.get());

    shoulder.set_angle(&acrobot_context, M_PI);
    elbow.set_angle(&acrobot_context, 0);
    double max_TE = acrobot.CalcPotentialEnergy(acrobot_context);
    std::cout << "max_TE: " << max_TE << std::endl;
    shoulder.set_angle(&acrobot_context, 0);
    double min_TE = acrobot.CalcPotentialEnergy(acrobot_context);
    std::cout << "min_TE: " << min_TE << std::endl;

    x_logger->set_publish_period(time_step);
    control_logger->set_publish_period(time_step); 
    simulator.set_publish_every_time_step(false);

    int steps_done = 0; 
    std::vector<double> epoch_list;
    std::vector<double> reward_list; 
    for (int epoch = 0; epoch < options.epochs; epoch++) {
        std::cout << epoch << std::endl;
        simulator.get_mutable_context().set_time(0.0);
        simulator.get_system().SetRandomContext(&simulator.get_mutable_context(),
                                                    &generator);
        x_logger->reset();
        control_logger->reset();
        simulator.Initialize();

        int num_steps = int(FLAGS_simulation_time / time_step);
        float loss = 0; 
        float reward = 0; 
        std::pair<float,float> dueling_q; 
        bool in_the_zone = false; 
        double sum_angle_0 = 0; 
        std::cout << reward_list.size() << std::endl;
        for(int t=0; t<num_steps; t++){
            
            int last_element_ctrl = control_logger->data().cols() - 1; 
            int last_element_x = x_logger->data().cols() - 1; 
            assert(last_element_ctrl == last_element_x); 
            int last_element = last_element_x; 
            
            if(last_element < 0){
                std::cout << "Yeah, this happened!" << std::endl; 
                simulator.StepTo(t*time_step);
                continue; 
            }

            Transition trans;
            VectorX<double> ctrl_inp = control_logger->data().col(last_element);
            VectorX<double> state = x_logger->data().col(last_element);
            // hacked_controller->SetOutput(ctrl_inp);
            trans.state = state.cast<float>();
            trans.action = int64_t(dqn.SelectAction(trans.state, steps_done, t));
            auto action_vector = dqn.ActionIntToVector(trans.action); 
            hacked_controller->SetOutput(action_vector);

            const systems::Context<double>& now_context = diagram->GetSubsystemContext(acrobot, simulator.get_context());

            double now_energy = acrobot.CalcKineticEnergy(now_context) +
                    acrobot.CalcPotentialEnergy(now_context);

            // step
            simulator.StepTo(t*time_step);
            last_element_x = x_logger->data().cols() - 1; 
            VectorX<double> next_state = x_logger->data().col(last_element_x);
            trans.next_state = next_state.cast <float> ();
            sum_angle_0 = trans.next_state(0) - trans.state(0);
            float velocity_error_n = fabs(goal_state(2) - trans.next_state(2)) + fabs(goal_state(3) - trans.next_state(3));
            float velocity_error_0 = fabs(goal_state(2) - trans.state(2)) + fabs(goal_state(3) - trans.state(3));
            
            float x_elbow_n = sin(trans.next_state(0));
            float y_elbow_n = cos(M_PI - trans.next_state(0)); 
            float dx_tip_n = sin(trans.next_state(0) + trans.next_state(1));
            float dy_tip_n = cos(M_PI - trans.next_state(0) + trans.next_state(1));
            float dist_n = pow(pow(x_elbow_n + dx_tip_n, 2.0) + pow(2.0 - y_elbow_n - dy_tip_n,2.0),0.5);  
            
            float x_elbow_0 = sin(trans.state(0));
            float y_elbow_0 = cos(M_PI - trans.state(0)); 
            float dx_tip_0 = sin(trans.state(0) + trans.state(1));
            float dy_tip_0 = cos(M_PI - trans.state(0) + trans.state(1));
            float dist_0 = pow(pow(x_elbow_0 + dx_tip_0, 2.0) + pow(2.0 - y_elbow_0 - dy_tip_0,2.0),0.5);
            trans.done = false; 

            const systems::Context<double>& next_context = diagram->GetSubsystemContext(acrobot, simulator.get_context());

            double next_energy = acrobot.CalcKineticEnergy(next_context) +
                    acrobot.CalcPotentialEnergy(next_context);
            // if (total_energy > max_TE){
            //     trans.reward = max_TE - total_energy;
            // } else {
            //     trans.reward = total_energy - max_TE;
            // }
            double delta_energy = pow(pow(now_energy - max_TE, 2.0), 0.5) -
                        pow(pow(next_energy - max_TE, 2.0), 0.5); 
            // trans.reward = 100 * delta_energy / pow(pow(next_energy - max_TE, 2.0), 0.5);
            
            // trans.reward = 10*(dist_0 - dist_n); // + 0.01*(velocity_error_0 - velocity_error_n); // - dist_0; //float(-1 *( (goal_state - trans.next_state).norm() - (goal_state - trans.state).norm())); // - float(0.1*action_vector.norm()); // - 10 * velocity_error; 
            // if (dist_n < 0.75 ){
            //     trans.reward += 20.0*(1.0 - dist_n / 0.75); //0.5 * trans.next_state(0); //0.1; 
            // }
            if (dist_n < 0.2 ){
                in_the_zone = true; 
                trans.reward = 1.0;
            }
            // if (in_the_zone && fabs(M_PI - trans.next_state(0)) > 0.5){
            //     trans.done = true; 
            // }

            // if (fabs(M_PI - trans.next_state(0)) > M_PI / 8.0 ||
            //         fabs(trans.next_state(1)) > M_PI / 8.0){
            //     trans.done = true;
            // }

            if (dist_n > 0.6 ){
                trans.done = true;
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
        
        std::cout << "q policy: " << dueling_q.first << " vs. q target: " << dueling_q.second << std::endl; 
        std::cout << "sum reward: " << reward << std::endl; 
        std::cout << "memory size: " << memory.size() << std::endl; 
        reward_list.push_back(reward);
        epoch_list.push_back(epoch);
        std::cout << "about to call visdom\n";
        // viz.Line(epoch_list, reward_list);
        std::cout << "after visdom call\n";
        if(epoch % options.log_interval == 0){
            std::cout << "Updating Target Net...\n";
            dqn.UpdateTargetNet(); 

        }
        
        assert(x_logger->sample_times().size() == control_logger->sample_times().size());

        // std::cout << x_logger->sample_times().size() << std::endl; 
        // std::cout << x_logger->data().rows() << std::endl; 
        // std::cout << x_logger->data().cols() << std::endl; 
        // std::cout << control_logger->sample_times().size() << std::endl; 
        // std::cout << control_logger->data().rows() << std::endl; 
        // std::cout << control_logger->data().cols() << std::endl; 
    }

    // std::vector<std::tuple<double,VectorX<double>,double>> result; 
    // int num_samples = x_logger->sample_times().size();
    // for(int i=0; i<num_samples; i++){
    //     double t = x_logger->sample_times()(i);
    //     VectorX<double> vec = x_logger->data().col(i); 
    //     double control = control_logger->data().col(i)(0); 
    //     auto tuple = std::make_tuple(t, vec, control);
    //     result.push_back(tuple);
    // }

}
}  // namespace
}  // namespace acrobot
}  // namespace multibody
}  // namespace examples
}  // namespace drake

int main(int argc, char* argv[]) {
  gflags::SetUsageMessage(
      "A simple acrobot demo using Drake's MultibodyPlant with "
      "LQR stabilization. "
      "Launch drake-visualizer before running this example.");
  gflags::ParseCommandLineFlags(&argc, &argv, true);
  drake::logging::HandleSpdlogGflags();
  return drake::examples::multibody::acrobot::do_main();
}
