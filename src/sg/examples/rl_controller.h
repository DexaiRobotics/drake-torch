/// @file: rl_controller.h
#pragma once

#include <torch/torch.h>

#include <utility>
#include <vector>
#include <math.h>       /* exp */
#include <random>

#include "drake/systems/controllers/pid_controller.h"
#include "drake/systems/controllers/rbt_inverse_dynamics.h"
#include "drake/systems/framework/diagram_builder.h"
#include "drake/systems/framework/leaf_system.h"
#include "drake/systems/primitives/adder.h"
#include "drake/systems/primitives/pass_through.h"

#include "rl_memory.h"

namespace drake {
namespace systems {
namespace controllers {

struct PytorchModel : torch::nn::Module {
public:
    torch::Tensor forward(torch::Tensor x);
}; 

template <typename T>
torch::Tensor EigenToTensor(const VectorX<T> &ev){
    // tensor output size 1xN = batch x N
    // allocate a tensor of the appropriate size
    int ev_size = ev.size();
    torch::Tensor output_tensor = torch::zeros({1, ev_size}, torch::dtype(torch::kFloat32));
    for(int i=0; i<ev_size; i++){
        output_tensor[0][i] = float(ev(i));
    }
    return output_tensor.to(torch::kFloat); 
}

template <typename T>
VectorX<T> TensorToEigen(torch::Tensor &foo){
    // assert foo is 2-dimensional and holds floats.
    auto foo_a = foo.accessor<float,2>();
    auto ev = VectorX<T>::Zero(foo_a.size(1)); 
    for(int i = 0; i < foo_a.size(1); i++) {
        // use the accessor foo_a to get tensor data.
        ev(i) = T(foo_a[0][i]);
    }
    return ev; 
}

template <typename T>
class PytorchController : public LeafSystem<T> {
public:
    PytorchController( PytorchModel& model,
                       const int num_inputs, const int num_outputs,
                       const torch::DeviceType device_type
    ): model_(model), num_inputs_(num_inputs), num_outputs_(num_outputs),
    device_(device_type) {
        this->DeclareInputPort(kVectorValued, num_inputs_);
        this->DeclareVectorOutputPort(BasicVector<T>(num_outputs_),
                                    &PytorchController<T>::ForwardPass);
    }

private:
    PytorchModel& model_;
    const int num_inputs_;
    const int num_outputs_;
    const torch::Device device_; 

    /**
     * Takes discrete vector input, passes it through a pytorch model
     * 
     */
    void ForwardPass(const Context<T>& context, BasicVector<T>* output) const {
        // get input from port and convert into a torch tensor
        const VectorX<float> x = this->EvalVectorInput(context, 0)->get_value();
        // const auto& u0 = system.EvalEigenVectorInput(context, 0); // same as above?
        auto output_tensor = model_.forward( EigenToTensor<float>(x).to(device_) );
        auto output_vector = TensorToEigen<float>(output_tensor);
        output->get_mutable_value() = output_vector;
        // Convert to a basic vector
    }
};

// template <typename T>
class FixedOutputController : public LeafSystem<double> {
public:
    FixedOutputController( const int num_inputs,
                           const int num_outputs,
                           VectorX<double> initial_output) : 
    num_inputs_(num_inputs), num_outputs_(num_outputs)
    {
        output_vector_ = initial_output; 
        this->DeclareInputPort(kVectorValued, num_inputs_);
        this->DeclareVectorOutputPort(BasicVector<double>(num_outputs_),
                                    &FixedOutputController::FixedOutput);
    }
    void SetOutput(const VectorX<double>& new_output_vector) {
        output_vector_ = new_output_vector; 
    }

 private:
    VectorX<double> output_vector_;
    const int num_inputs_;
    const int num_outputs_;

    /**
     * Takes discrete vector input, passes it through a pytorch model
     * 
     */
    void FixedOutput(const Context<double>& context, BasicVector<double>* output) const {
        // get input from port and convert into a torch tensor
        const Eigen::VectorXd x = this->EvalVectorInput(context, 0)->get_value();
        // const auto& u0 = system.EvalEigenVectorInput(context, 0); // same as above?
        // Convert to a basic vector
        output->get_mutable_value() = output_vector_; 
    }

    
};

// std::unique_ptr<MakeFixedOutputController> 
// MakeFixedOutputController(const int num_inputs,
//                           const int num_outputs,
//                           VectorX<double> initial_output){
//     return std::make_unique<FixedOutputController>();
//                           }

}  // namespace controllers
}  // namespace systems
}  // namespace drake

namespace drake {
    using systems::controllers::EigenToTensor;
    using systems::controllers::TensorToEigen; 
namespace examples {
namespace multibody {
namespace {

struct Net : systems::controllers::PytorchModel {
public:
    Net() {
        // Construct and register two Linear submodules.
        fc1 = register_module("fc1", torch::nn::Linear(4, 16));
        fc2 = register_module("fc2", torch::nn::Linear(16, 32));
        fc3 = register_module("fc3", torch::nn::Linear(32, 64));
        fc4 = register_module("fc4", torch::nn::Linear(64, 64));
        adv = register_module("adv", torch::nn::Linear(64, 1));
        val = register_module("val", torch::nn::Linear(64, 2));
    }

    // Implement the Net's algorithm.
    torch::Tensor forward(torch::Tensor x) {
        // Use one of many tensor manipulation functions.
        x = torch::tanh(fc1->forward(x.reshape({x.size(0), 4})));
        // x = torch::dropout(x, /*p=*/0.5, /*train=*/is_training());
        x = torch::tanh(fc2->forward(x));
        x = torch::tanh(fc3->forward(x));
        x = torch::tanh(fc4->forward(x));
        auto advantage = adv->forward(x);
        auto value = val->forward(x); 
        x = value + advantage - advantage.mean(); 
        return x;
    }

  // Use one of many "standard library" modules.
  torch::nn::Linear fc1{nullptr}, fc2{nullptr}, fc3{nullptr}, fc4{nullptr}, adv{nullptr}, val{nullptr}; //, fc4{nullptr}; //fc2{nullptr}, fc3{nullptr},
};

// TORCH_MODULE(Net); 

struct Options {
    std::string data_root{"./data"};
    int32_t batch_size{128};
    int32_t epochs{100000};
    double lr{0.01};
    double momentum{0.05};
    bool no_cuda{false};
    int32_t seed{1};
    int32_t test_batch_size{1000};
    int32_t log_interval{10};
    torch::DeviceType device_type{torch::kCPU};
    int32_t dim_action_space{2}; // add or subtract torque 
    int32_t eps_decay{50};
    double eps_start{0.95};
    double eps_end{0.15}; 
    double action_mag{20.0}; 
    double gamma{0.999};
    Options(bool set_cuda_false=false) : no_cuda(set_cuda_false) {
        if (torch::cuda::is_available() && !no_cuda) {
            std::cout << "CUDA available! Training on GPU" << std::endl;
            device_type = torch::kCUDA;
        } else {
            std::cout << "Training on CPU" << std::endl;
            device_type = torch::kCPU;
        }
        // device_type = torch::kCPU;
    }

};

class DQN {
public:
    DQN(Options opt): options(opt), device(options.device_type) {
        policy_model = new Net; 
        target_model = new Net;   
        policy_model->to(device);
        target_model->to(device); 
        policy_model->train();
        target_model->eval();

        optimizer = new torch::optim::SGD (
            policy_model->parameters(),
            torch::optim::SGDOptions(options.lr).momentum(options.momentum));
    }

    std::pair<float, float> Optimize(ReplayMemory memory){
        // randomly sample a batch to use
        torch::autograd::GradMode::set_enabled(true);
        if(memory.size() < options.batch_size) {
            std::cout << "filling up memory: " << memory.size() << std::endl; 
            return std::make_pair(0,0); 
        }
        auto batch = memory.Sample(options.batch_size); 
        auto states_tensor = batch.states.to(device); 
        auto non_final_states_tensor = batch.non_final_states.to(device); 
        auto actions_tensor = batch.actions.to(device); 
        auto next_states_tensor = batch.next_states.to(device); 
        auto rewards_tensor = batch.rewards.to(device);
        // std::cout << "batch.actions size: " << batch.actions.size(0) << ", " << batch.actions.size(1) << std::endl; 
        // std::cout << batch.actions << std::endl; 
        // Compute Q(s_t, a) - the model computes Q(s_t), then we select the columns of actions taken
        auto policy_output = policy_model->forward(states_tensor); // batch_size x output_size

        // std::cout << "policy_output size: " << policy_output.size(0) << ", " << policy_output.size(1) << std::endl; 
        
        auto q_based_on_action = policy_output.gather(1, actions_tensor); 
        // std::cout << "q_action: " << q_based_on_action[0].item<float>() << std::endl;
        // Compute V(s_{t+1}) for all next states.

        auto predicted_q_next_state = target_model->forward(next_states_tensor).detach(); 
        
        std::cout << "###################\n";
        std::cout << "states: " << states_tensor[0] << std::endl;
        std::cout << "actions: " << actions_tensor[0] << std::endl;
        std::cout << "next_states: " << next_states_tensor[0] << std::endl; 
        std::cout << "policy: " << policy_output[0] << std::endl; 
        std::cout << "predicted q next state: " << predicted_q_next_state[0] << std::endl; 
        std::cout << "next_states size: " << next_states_tensor.size(0) << ", "
                << next_states_tensor.size(1) << std::endl; 
        std::cout << "non final states: " << non_final_states_tensor[0] << std::endl;
        
        auto next_state_q_values = std::get<0>(predicted_q_next_state.max(1)).unsqueeze(1); //
        // std::cout << next_state_q_values[0].item<float>() << std::endl;
        next_state_q_values = torch::mul(next_state_q_values, non_final_states_tensor);
        // \gamma * (max a_{t+1}) Q^{pi}(s_{t+1}, a) + r(s_t, a_t)
        // std::cout << batch.non_final_states << std::endl; 
        // std::cout << "next_state_q_values size: " << next_state_q_values.size(0) << ", " << next_state_q_values.size(1) << std::endl; 
        auto expected_q_values = float(options.gamma) * next_state_q_values + rewards_tensor;

        // std::cout << expected_q_values << std::endl;
        // std::cout << q_based_on_action << std::endl;
        
        // \delta = Q(s,a) - (r + \gamma * (max a_{t+1})Q(s_{t+1},a_{t+1}))
        std::cout << "q_based_on_action size: " << q_based_on_action.size(0) << ", " << q_based_on_action.size(1) << std::endl; 
        std::cout << "expected_q_values size: " << expected_q_values.size(0) << ", " << expected_q_values.size(1) << std::endl; 
        
        auto loss = torch::mse_loss(q_based_on_action, rewards_tensor); //expected_q_values
        std::cout << "loss: " << loss.item<float>() << std::endl; 
        optimizer->zero_grad();
        std::cout << "optimizer zero-ed." << std::endl; 
        if(std::isnan(loss.item<float>())){
            std::cout << "NaN loss??" << std::endl; 
            return std::make_pair(0,0);
        }
        AT_ASSERT(!std::isnan(loss.item<float>()));
        std::cout << "pre loss." << std::endl;
        loss.backward();
        std::cout << "loss backward-ed." << std::endl;
        for(auto& param : policy_model->parameters()){
            param.grad().clamp_(-1, 1);
        }
        optimizer->step();
        auto dueling_q = std::make_pair(q_based_on_action[0].detach().item<float>(), expected_q_values[0].detach().item<float>() ); //loss.item<float>()
        std::cout << "q policy: " << dueling_q.first << " vs. q target: " << dueling_q.second << std::endl;
        return dueling_q;
    }

    int SelectAction(VectorX<float>& state, int steps_done,
                     int steps_in_episode
    ){
        int64_t chosen_action=0; 
        std::random_device rd;
        std::mt19937 e2(rd());
        std::uniform_real_distribution<> dist(0, 1);

        double step_fraction = steps_done / (steps_in_episode+1); 
        double decay_value = -1. * step_fraction  / options.eps_decay;
        double eps_threshold = options.eps_end + (options.eps_start - options.eps_end) * exp(decay_value);
        double sample = dist(e2); 
        if(sample > eps_threshold){
            // choose based on network
            // no grad??
            torch::NoGradGuard guard;
            torch::Tensor state_tensor = EigenToTensor(state).to(device);
            auto output = std::get<1>(policy_model->forward(state_tensor).max(1)); //
            // std::cout << "policy_model action: " << output.item<int64_t>() << std::endl; 
            chosen_action = output.item<int64_t>(); 
        } else {
            // make a random choice
            std::uniform_real_distribution<> action_dist(0, options.dim_action_space-1);
            chosen_action = std::round(action_dist(e2)); 
        }
        return chosen_action; 
    }

    VectorX<double> ActionIntToVector(int64_t action_int){
        // specific to the chosen model
        assert(action_int == 0 || action_int == 1);
        auto new_action = (action_int == 1) ? options.action_mag : -options.action_mag;
        auto out = VectorX<double>(1);
        out << new_action; 
 
        // std::cout << "torque: " << torque << std::endl; 
        return out; 
    }

    void UpdateTargetNet(){
        // *target_model = *policy_model;

        torch::autograd::GradMode::set_enabled(false);  // make parameters copying possible
        auto policy_params = policy_model->named_parameters(true /*recurse*/); //ReadStateDictFromFile(params_path); // implement this
        auto target_params = target_model->named_parameters(true /*recurse*/);
        auto policy_buffers = policy_model->named_buffers(true /*recurse*/);
        auto target_buffers = target_model->named_buffers(true /*recurse*/);
        for (auto& val : policy_params) {
            auto name = val.key();
            auto* t = target_params.find(name);
            if (t != nullptr) {
                t->copy_(val.value());
            } else {
                t = target_buffers.find(name);
                if (t != nullptr) {
                    t->copy_(val.value());
                }
            }
        }
        torch::autograd::GradMode::set_enabled(true);
        target_model->eval(); 
    }
private:
    const Options options; 
    torch::Device device;
    Net* policy_model;
    Net* target_model;
    torch::optim::SGD* optimizer;
    double torque{0.0};
};

}  // namespace
}  // namespace multibody
}  // namespace examples
}  // namespace drake