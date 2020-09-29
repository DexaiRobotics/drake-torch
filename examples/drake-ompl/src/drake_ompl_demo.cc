/// @file drake_ompl_demo.cc
// @author: David M.S. Johnson <dave@dexai.com>

#include <memory>
#include <gflags/gflags.h>
#include <iostream>
#include <chrono>
#include <thread>

#include "drake/multibody/plant/multibody_plant.h"
#include "drake/common/drake_assert.h"
#include "drake/common/find_resource.h"
#include "drake/geometry/geometry_visualization.h"
#include "drake/geometry/scene_graph.h"
#include "drake/systems/analysis/simulator.h"
#include "drake/systems/framework/diagram.h"
#include "drake/systems/framework/diagram_builder.h"
#include "drake/multibody/parsing/parser.h"

#include <ompl/config.h>
#include <ompl/geometric/SimpleSetup.h>
#include <ompl/base/SpaceInformation.h>
#include <ompl/base/spaces/RealVectorStateSpace.h>
#include <ompl/base/objectives/PathLengthOptimizationObjective.h>
#include <ompl/geometric/planners/rrt/InformedRRTstar.h>
#include <ompl/geometric/planners/rrt/RRTConnect.h>


using drake::geometry::SceneGraph;
using drake::geometry::SignedDistancePair;
using drake::multibody::ModelInstanceIndex;
using drake::multibody::MultibodyPlant;
using drake::systems::Context;
using drake::geometry::GeometrySet;
using drake::geometry::QueryObject;
using drake::math::RigidTransform;
using drake::multibody::Body;
using drake::multibody::BodyIndex;
using drake::multibody::Parser;
using drake::multibody::AddMultibodyPlantSceneGraph;
using namespace Eigen;
namespace ob = ompl::base;
namespace og = ompl::geometric;


DEFINE_string(urdf, "", "Name of urdf to load");
DEFINE_double(sim_dt, 3e-3,
              "The time step to use for MultibodyPlant model "
              "discretization.");
DEFINE_double(discretization, 1e-2,
              "The OMPL RealVectorSpace "
              "discretization in radians.");
DEFINE_double(collision_tolerance, 1e-3,
              "The collision tolerance (meters) to use for OMPL planning.");
DEFINE_double(max_distance, 0.5,
              "The maximum distance in meters at which distance data is reported during collision checking.");
DEFINE_double(solve_time, 15.0,
              "The time to spend trying to solve the OMPL planning problem.");
DEFINE_double(simplify_time, 10.0,
              "The time to spend to try and simplify the solution to the OMPL planning problem.");
DEFINE_int32(pause_msec, 150,
              "Determines Playback speed. Time to pause between displaying each solution state in msec.");
DEFINE_int32(cycles_to_display, 100,
              "Determines how long the solution is played back. Each cycle is num_interpolated_states * pause_msec * 2 /1000 seconds long.");
DEFINE_int32(num_interpolated_states, 50,
              "Determines Playback speed. Number of states in the OMPL trajectory to display.");

Eigen::VectorXd OMPLStateToEigen(const ompl::base::State* state, int size) {
  Eigen::VectorXd state_vector = Eigen::VectorXd::Zero(size);
  const ompl::base::RealVectorStateSpace::StateType* pos =
      state->as<ompl::base::RealVectorStateSpace::StateType>();
  for (int i = 0; i < size; i++) {
    state_vector(i) = (*pos)[i];
  }
  return state_vector;
}

std::vector<double> eigen_to_vec(Eigen::VectorXd e) {
  std::vector<double> v;
  v.resize(e.size());
  Eigen::VectorXd::Map(&v[0], e.size()) = e;
  return v;
}

int main(int argc, char* argv[]) {
  gflags::ParseCommandLineFlags(&argc, &argv, true);
  //
  drake::systems::DiagramBuilder<double> builder;
  // create a scene graph that contains all the geometry of the system.
  auto [plant, scene_graph] = AddMultibodyPlantSceneGraph(
      &builder, FLAGS_sim_dt);
  scene_graph.set_name("scene_graph");

  // define our geometry source
  // const std::string robot_urdf_filepath{"iiwa14_boxes.urdf"};
  const char* kModelPath =
      "drake/manipulation/models/iiwa_description/"
      "urdf/iiwa14_spheres_dense_elbow_collision.urdf";
  const std::string robot_root_link_in_urdf{"base"};
  const std::string urdf =
      (!FLAGS_urdf.empty() ? FLAGS_urdf : drake::FindResourceOrThrow(kModelPath));

  // import geometry
  ModelInstanceIndex robot_model_idx_ =
        Parser(&plant, &scene_graph).AddModelFromFile(urdf, "iiwa14");

  // obtain vector of Body Indices for each model for the Geometry Sets
  std::vector<BodyIndex> robot_body_indices = plant.GetBodyIndices(robot_model_idx_);
  std::vector<const Body<double>*> robot_bodies;
  for (size_t k = 0; k < robot_body_indices.size(); k++) {
    robot_bodies.push_back(&plant.get_body(robot_body_indices[k]));
  }

  auto& child_frame = plant.GetFrameByName(robot_root_link_in_urdf, robot_model_idx_);
  plant.WeldFrames(plant.world_frame(), child_frame);

  // add some boxes in a grid for collision geometry
  // 2x2x3 grid with some missing boxes to support the location of the arm
  Eigen::Vector3d box_cluster_origin {-1.1, 0.8, 0.35}; // meters, arm is at 0,0,0
  auto box_cluster_rpy = Eigen::Vector3d::Zero();
  Eigen::Vector3d grid_offset{1.1, -0.8, 0.95}; // meters
  Eigen::Vector3i num_boxes{3, 2, 2};
  Eigen::VectorXd populated_boxes = Eigen::VectorXd::Zero(12); // 3*2*2
  populated_boxes << 1, 1, 1, // front row, bottom
                     0, 0, 0, // back row, bottom, with arm
                     1, 1, 1, // top row, front
                     1, 1, 1; // back row, front
  // populated_boxes << 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1;
  const std::string box_root_link{"base_link"};
  size_t tot_idx{0};
  for(size_t z_idx=0; z_idx<num_boxes(2); z_idx++) {
    for(size_t y_idx=0; y_idx<num_boxes(1); y_idx++) {
      for(size_t x_idx=0; x_idx<num_boxes(0); x_idx++) {
        if(populated_boxes(tot_idx)>0) {
          const std::string box_name{"box_"+std::to_string(tot_idx)};
          auto box_idx = Parser(&plant, &scene_graph)
                                    .AddModelFromFile("box.sdf", box_name);
          Eigen::Vector3d box_offset {x_idx, y_idx, z_idx};
          RigidTransform<double> X_WorldToBox(drake::math::RollPitchYaw<double>(box_cluster_rpy),
                                              box_cluster_origin + box_offset.cwiseProduct(grid_offset));
          auto& child_frame =
                plant.GetFrameByName(box_root_link, box_idx);
          plant.WeldFrames(plant.world_frame(), child_frame, X_WorldToBox);
        }
        tot_idx++;
      }
    }
  }
  // Now the model is complete.
  plant.Finalize();

  auto robot_dof_ = plant.num_positions(robot_model_idx_);
  std::cerr << "RobotCollisionChecker: robot_dof_: " << robot_dof_ << std::endl;

  // Sanity check on the availability of the optional source id before using it.
  DRAKE_DEMAND(!!plant.get_source_id());

  // connect the visualizer and make the context
  drake::geometry::ConnectDrakeVisualizer(&builder, scene_graph);

  std::unique_ptr<drake::systems::Diagram<double>> diagram_ = builder.Build();
  std::unique_ptr<drake::systems::Context<double>> context_ = diagram_->CreateDefaultContext();
  diagram_->SetDefaultContext(context_.get());
  auto scene_context = scene_graph.AllocateContext();
  auto output = diagram_->AllocateOutput();

  // create a simulator for visualization
  std::unique_ptr<drake::systems::Simulator<double>> simulator_ = std::make_unique<drake::systems::Simulator<double>>(*diagram_);
  simulator_->Initialize();
  drake::systems::Context<double>* plant_context =
      &diagram_->GetMutableSubsystemContext(plant, &simulator_->get_mutable_context());

  // initialize to a default position (may be in collision)
  plant.SetPositions(plant_context, robot_model_idx_, Eigen::VectorXd::Zero(robot_dof_));
  simulator_->get_system().Publish(simulator_->get_context());

  // setup the OMPL planning problem
  // ompl::msg::noOutputHandler(); // uncomment to remove OMPL messages

  // create the vector space and use SimpleSetup
  auto space_ = std::make_shared<ob::RealVectorStateSpace>(robot_dof_);
  DRAKE_DEMAND(space_ && "NULL space_");
  ob::RealVectorBounds bounds(space_->getDimension());
  VectorXd pos_upper_limits = plant.GetPositionUpperLimits();
  VectorXd pos_lower_limits = plant.GetPositionLowerLimits();
  DRAKE_DEMAND(pos_upper_limits.size()==robot_dof_);
  DRAKE_DEMAND(pos_lower_limits.size()==robot_dof_);
  for (uint i = 0; i < uint(robot_dof_); i++) {
      bounds.setHigh(i, pos_upper_limits(i));
      bounds.setLow(i, pos_lower_limits(i));
  }
  space_->setBounds(bounds);
  // define a simple setup class
  og::SimpleSetup ss(space_);
  auto si = ss.getSpaceInformation();
  // setup the Validty Checker as a lambda function which returns a bool
  ss.setStateValidityChecker([&plant, plant_context, &simulator_, &robot_model_idx_, &robot_dof_, &FLAGS_collision_tolerance](const ob::State* state) {
    auto next_conf = OMPLStateToEigen(state, robot_dof_); // copy
    plant.SetPositions(plant_context, robot_model_idx_, next_conf);
    // Query port & object used to find out results from scene graph
    const auto& query_port = plant.get_geometry_query_input_port();
    if (!query_port.HasValue(*plant_context)) {
      throw std::invalid_argument(
          "Cannot get a valid geometry::QueryObject. "
          "Either the plant geometry_query_input_port() is not properly "
          "connected to the SceneGraph's output port, or the plant_context is "
          "incorrect. Please refer to AddMultibodyPlantSceneGraph on connecting "
          "MultibodyPlant to SceneGraph.");
    }
    const auto& query_object = query_port.Eval<QueryObject<double>>(*plant_context);

    // method is based on https://github.com/RobotLocomotion/drake/issues/11580
    std::vector<SignedDistancePair<double>> signed_distance_pairs = query_object.ComputeSignedDistancePairwiseClosestPoints(FLAGS_max_distance);

    bool is_collision_free = true; // return value
    for (const auto& signed_distance_pair : signed_distance_pairs) {
      // stop once any collision is detected:
      if (signed_distance_pair.distance < FLAGS_collision_tolerance) {
        // uncomment to display info on the colliding object; warning, very verbose
        // const auto& inspector = query_object.inspector();
        // const auto& name_A = inspector.GetName(signed_distance_pair.id_A);
        // const auto& name_B = inspector.GetName(signed_distance_pair.id_B);
        // drake::log()->info("{} <--> {} is: {}", name_A, name_B, signed_distance_pair.distance);
        is_collision_free = false;
        return is_collision_free;
      }
    }
    return is_collision_free;
  });
  // further setup the OMPL planning specifications
  ss.getSpaceInformation()->setStateValidityCheckingResolution(FLAGS_discretization);
  // set the desired planner
  ss.setPlanner(std::make_shared<og::RRTConnect>(si)); //InformedRRTstar

  // define the states between which to compute a trajectory
  Eigen::VectorXd start_conf = Eigen::VectorXd::Zero(robot_dof_);
  start_conf <<  0.391309,     1.19062,     0.891649,    -0.863306,     0.694499,     0.512097, 0;
  Eigen::VectorXd goal_conf = Eigen::VectorXd::Zero(robot_dof_);
  goal_conf  << -0.391345,    -1.19056,    -0.891491,     0.863343,    -0.694777,    -0.512052, 0;

  ompl::base::ScopedState<> start(space_);
  start = eigen_to_vec(start_conf);  // dru::e_to_v(start_conf);
  ompl::base::ScopedState<> goal(space_);
  goal = eigen_to_vec(goal_conf);
  ss.setStartAndGoalStates(start, goal);
  // this call is optional, but we put it in to get more output information
  ss.setup();
  ss.print();

  std::vector<Eigen::VectorXd> trajectory;
  if (ss.solve(FLAGS_solve_time) == ob::PlannerStatus::EXACT_SOLUTION ) {
    ss.simplifySolution(FLAGS_simplify_time);
    og::PathGeometric path = ss.getSolutionPath();
    // Return solution from OMPL problem definition and convert to Eigen type
    drake::log()->info("path length {} and size {} BEFORE interpolation", path.length(),
                path.getStates().size());
    path.interpolate(FLAGS_num_interpolated_states);
    drake::log()->info("path length {} and size {} AFTER interpolation", path.length(),
                path.getStates().size());
    std::vector<ob::State*> path_states = path.getStates();

    for (auto& ompl_state : path_states) {
      trajectory.push_back(OMPLStateToEigen(ompl_state, robot_dof_));
    }
  } else {
    return 1;
  }

  size_t num_cycles{0};
  while(num_cycles < FLAGS_cycles_to_display){
    for(size_t ii=0; ii<2; ii++) {
      for(const auto& conf : trajectory) {
        plant.SetPositions(plant_context, robot_model_idx_, conf);
        simulator_->get_system().Publish(simulator_->get_context());
        std::this_thread::sleep_for(std::chrono::milliseconds(FLAGS_pause_msec));
      }
      std::reverse(std::begin(trajectory), std::end(trajectory));
    }
    num_cycles++;
  }

  std::cerr << "Planning Complete!" << std::endl;
  return 0;
}