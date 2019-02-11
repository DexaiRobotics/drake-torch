/// @file: drake_cartpole_env.h
#pragma once

#include <memory>
#include <cmath>
#include <cstdlib>
#include <random>

#include <torch/data.h>
#include <torch/nn/modules/batchnorm.h>
#include <torch/nn/modules/conv.h>
#include <torch/nn/modules/dropout.h>
#include <torch/nn/modules/linear.h>
#include <torch/optim/adam.h>
#include <torch/optim/optimizer.h>
#include <torch/optim/sgd.h>
#include <torch/types.h>
#include <torch/utils.h>

#include <test/cpp/api/support.h>

#include "drake/common/drake_assert.h"
#include "drake/common/find_resource.h"
// #include "drake/common/text_logging_gflags.h"
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

#include "rl_controller.h"

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

class CartPole {
  // Translated from openai/gym's cartpole.py
private:
    const double time_step;
    const double target_realtime_rate_;
    const bool time_stepping_;
    const double simulation_time_;
    double gravity = 9.8;
    double masscart = 1.0;
    double masspole = 0.1;
    double total_mass = (masspole + masscart);
    double length = 0.5; // actually half the pole's length;
    double polemass_length = (masspole * length);
    double force_mag = 100.0;
    double force = 0.0;
    double force_incr = 0.02; 
    double tau = 0.02; // seconds between state updates;

    // Angle at which to fail the episode
    double theta_threshold_radians = 12 * 2 * M_PI / 360;
    double x_threshold = 2.4;
    int steps_beyond_done = -1;

    torch::Tensor state;
    double reward;
    bool done;
    int step_ = 0;

    systems::DiagramBuilder<double>* builder;
    SceneGraph<double>* scene_graph;
    std::unique_ptr<Diagram<double>> diagram;
    systems::SignalLogger<double>* x_logger; 
    std::unique_ptr<systems::Simulator<double>> simulator;
    systems::controllers::FixedOutputController* hacked_controller;
    RandomGenerator* generator;

public:
    CartPole(double target_realtime_rate, double simulation_time, bool time_stepping);
    ~CartPole(){}; 
    torch::Tensor getState() {
        return state;
    }

    double getReward() {
        return reward;
    }

    double isDone() {
        return done;
    }

    VectorX<double> ActionIntToVector(int64_t action_int);

    void reset();
    void step(int action);
};

// }  // namespace
}  // namespace cart_pole
}  // namespace multibody
}  // namespace examples
}  // namespace drake