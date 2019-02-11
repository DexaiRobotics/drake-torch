#include "drake_cartpole_env.h"

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
// namespace {

CartPole::CartPole(double target_realtime_rate, double simulation_time, bool time_stepping) :
    time_step(time_stepping ? 1.0e-2 : 0.0), time_stepping_(time_stepping), 
    target_realtime_rate_(target_realtime_rate), simulation_time_(simulation_time)
{ 
    builder = new systems::DiagramBuilder<double>();

    scene_graph = builder->AddSystem<SceneGraph>();
    scene_graph->set_name("scene_graph");

    // Make and add the cart_pole model.
    const std::string relative_name =
        "drake/examples/multibody/cart_pole/cart_pole.sdf";
    const std::string full_name = FindResourceOrThrow(relative_name);
    MultibodyPlant<double>& cart_pole =
        *builder->AddSystem<MultibodyPlant>(time_step);

    Parser parser(&cart_pole, scene_graph);
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

    hacked_controller = builder->AddSystem(
        std::make_unique<systems::controllers::FixedOutputController>(4, 1, VectorX<double>::Zero(1) ));
    builder->Connect(cart_pole.get_continuous_state_output_port(),
                    hacked_controller->get_input_port(0));
    builder->Connect(hacked_controller->get_output_port(0),
                    cart_pole.get_actuation_input_port());

    // Sanity check on the availability of the optional source id before using it.
    DRAKE_DEMAND(!!cart_pole.get_source_id());

    builder->Connect(
        cart_pole.get_geometry_poses_output_port(),
        scene_graph->get_source_pose_port(cart_pole.get_source_id().value()));

    geometry::ConnectDrakeVisualizer(builder, *scene_graph);

    // Log the true state and the control output.
    x_logger = systems::LogOutput(cart_pole.get_continuous_state_output_port(), builder);
    x_logger->set_name("x_logger");

    diagram = builder->Build();

    // Create a context for this system:
    std::unique_ptr<systems::Context<double>> diagram_context =
            diagram->CreateDefaultContext();
    diagram->SetDefaultContext(diagram_context.get());
    systems::Context<double>& cart_pole_context =
            diagram->GetMutableSubsystemContext(cart_pole, diagram_context.get());
    // Set initial state.
    cart_slider.set_translation(&cart_pole_context, 0.0);

    simulator = std::make_unique<systems::Simulator<double>>(*diagram);
    simulator->set_target_realtime_rate(target_realtime_rate_);

    // Setup distribution for random initial conditions.
    generator = new RandomGenerator;
    std::normal_distribution<symbolic::Expression> gaussian;
    pole_pin.set_random_angle_distribution(M_PI + 0.05*gaussian(*generator));  

    x_logger->set_publish_period(time_step);


    reset();
}

void CartPole::reset() {
    steps_beyond_done = -1;
    step_ = 0;
    force = 0.0; 

    if(!simulator){
        std::cout << "Error! Make a simulator before calling reset." << std::endl; 
    }

    simulator->get_mutable_context().set_time(0.0);
    simulator->get_system().SetRandomContext(&simulator->get_mutable_context(),
                                            generator);
    simulator->set_publish_every_time_step(false);

    x_logger->reset();
    
    simulator->Initialize();
    
    int last_element_x = x_logger->data().cols() - 1; 
    // std::cout << x_logger->data().cols() << std::endl; 
    VectorX<double> state_eigen = x_logger->data().col(last_element_x);
    state = EigenToTensor(state_eigen).squeeze(0); 
    // std::cout << state << std::endl; 
    // state = torch::empty({4}).uniform_(-0.05, 0.05);

}

VectorX<double> CartPole::ActionIntToVector(int64_t action_int){
        // specific to the chosen model
        assert(action_int == 0 || action_int == 1);
        // apply left or right force?
        // force += (double(action_int) * 2.0 - 1.0) * force_incr; 
        // if(force > force_mag){
        //     force = force_mag;
        // } else if(force < -1*force_mag){
        //     force = -1*force_mag;
        // }

        auto new_force = (action_int == 1) ? force_mag : -force_mag;

        auto out = VectorX<double>(1);
        out << new_force; 
        // std::cout << "torque: " << torque << std::endl; 
        return out; 
    }

void CartPole::step(int action) {
    // auto x = state[0].item<float>();
    // auto x_dot = state[1].item<float>();
    // auto theta = state[2].item<float>();
    // auto theta_dot = state[3].item<float>();

    // auto force = (action == 1) ? force_mag : -force_mag;
    // auto costheta = std::cos(theta);
    // auto sintheta = std::sin(theta);
    // auto temp = (force + polemass_length * theta_dot * theta_dot * sintheta) /
    //     total_mass;
    // auto thetaacc = (gravity * sintheta - costheta * temp) /
    //     (length * (4.0 / 3.0 - masspole * costheta * costheta / total_mass));
    // auto xacc = temp - polemass_length * thetaacc * costheta / total_mass;

    // x = x + tau * x_dot;
    // x_dot = x_dot + tau * xacc;
    // theta = theta + tau * theta_dot;
    // theta_dot = theta_dot + tau * thetaacc;
    // state = torch::tensor({x, x_dot, theta, theta_dot});

    int last_element_x = x_logger->data().cols() - 1; 
    VectorX<double> state_eigen = x_logger->data().col(last_element_x);
    state = EigenToTensor(state_eigen).squeeze(0); 
    auto action_vector = ActionIntToVector(action); 
    hacked_controller->SetOutput(action_vector);

    // step
    step_++;
    simulator->StepTo(step_*time_step);
    last_element_x = x_logger->data().cols() - 1; 
    VectorX<double> next_state = x_logger->data().col(last_element_x);
    state = EigenToTensor(next_state).squeeze(0); 

    auto x = state[0].item<float>();
    auto theta = M_PI - state[1].item<float>();
    done = x < -x_threshold || x > x_threshold ||
        theta < -theta_threshold_radians || theta > theta_threshold_radians ||
        step_ > 600;

    if (!done) {
        reward = 1.0;
    } else if (steps_beyond_done == -1) {
        // Pole just fell!
        steps_beyond_done = 0;
        reward = 0;
    } else {
        if (steps_beyond_done == 0) {
            AT_ASSERT(false); // Can't do this
        }
    }
}

// }  // namespace
}  // namespace cart_pole
}  // namespace multibody
}  // namespace examples
}  // namespace drake