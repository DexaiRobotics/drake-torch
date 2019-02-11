#include <memory>

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
#include "drake/multibody/tree/uniform_gravity_field_element.h"
#include "drake/systems/analysis/simulator.h"
#include "drake/systems/controllers/linear_quadratic_regulator.h"
#include "drake/systems/framework/diagram_builder.h"
#include "drake/systems/primitives/affine_system.h"
#include "drake/systems/rendering/pose_bundle_to_draw_message.h"
#include "drake/systems/primitives/signal_logger.h"

namespace drake {

using geometry::SceneGraph;
using lcm::DrakeLcm;
using multibody::benchmarks::acrobot::AcrobotParameters;
using multibody::benchmarks::acrobot::MakeAcrobotPlant;
using multibody::MultibodyPlant;
using multibody::Parser;
using multibody::JointActuator;
using multibody::RevoluteJoint;
using multibody::UniformGravityFieldElement;
using systems::Context;
using systems::Diagram;

namespace examples {
namespace multibody {
namespace acrobot {
namespace {
// This helper method makes an LQR controller to balance an acrobot model
// specified in the SDF file `file_name`.
std::unique_ptr<systems::AffineSystem<double>> MakeBalancingLQRController(
    const std::string &file_name) {
  const std::string full_name = FindResourceOrThrow(file_name);
  // LinearQuadraticRegulator() below requires the controller's model of the
  // plant to only have a single input port corresponding to the actuation.
  // Therefore we create a new model that meets this requirement. (a model
  // created along with a SceneGraph for simulation would also have input ports
  // to interact with that SceneGraph).
  MultibodyPlant<double> acrobot;
  Parser parser(&acrobot);
  parser.AddModelFromFile(full_name);
  // Add gravity to the model.
  acrobot.AddForceElement<UniformGravityFieldElement>(
      -9.81 * Vector3<double>::UnitZ());
  // We are done defining the model.
  acrobot.Finalize();

  const RevoluteJoint<double>& shoulder =
      acrobot.GetJointByName<RevoluteJoint>("ShoulderJoint");
  const RevoluteJoint<double>& elbow =
      acrobot.GetJointByName<RevoluteJoint>("ElbowJoint");
  std::unique_ptr<Context<double>> context = acrobot.CreateDefaultContext();

  // Set nominal actuation torque to zero.
  context->FixInputPort(0, Vector1d::Constant(0.0));

  shoulder.set_angle(context.get(), M_PI);
  shoulder.set_angular_rate(context.get(), 0.0);
  elbow.set_angle(context.get(), 0.0);
  elbow.set_angular_rate(context.get(), 0.0);

  // Setup LQR Cost matrices (penalize position error 10x more than velocity
  // to roughly address difference in units, using sqrt(g/l) as the time
  // constant.
  Eigen::Matrix4d Q = Eigen::Matrix4d::Identity();
  Q(0, 0) = 10;
  Q(1, 1) = 10;
  Vector1d R = Vector1d::Constant(1);

  return systems::controllers::LinearQuadraticRegulator(
      acrobot, *context, Q, R);
}

}  // namespace
}  // namespace acrobot
}  // namespace multibody
}  // namespace examples
}  // namespace drake