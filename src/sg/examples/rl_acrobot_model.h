#include <torch/torch.h>
#include "rl_controller.h"

namespace drake {
namespace examples {
namespace multibody {
namespace acrobot {
namespace {

struct Net : systems::controllers::PytorchModel {
public:
    Net() {
        // Construct and register two Linear submodules.
        fc1 = register_module("fc1", torch::nn::Linear(4, 512));
        fc2 = register_module("fc2", torch::nn::Linear(512, 1024));
        fc3 = register_module("fc3", torch::nn::Linear(1024, 512));
        fc4 = register_module("fc4", torch::nn::Linear(512, 1));
    }

    // Implement the Net's algorithm.
    torch::Tensor forward(torch::Tensor x) {
        // Use one of many tensor manipulation functions.
        x = torch::relu(fc1->forward(x.reshape({x.size(0), 4})));
        // x = torch::dropout(x, /*p=*/0.5, /*train=*/is_training());
        x = torch::relu(fc2->forward(x));
        x = torch::relu(fc3->forward(x));
        x = fc4->forward(x); 
        return x;
    }

  // Use one of many "standard library" modules.
  torch::nn::Linear fc1{nullptr}, fc2{nullptr}, fc3{nullptr}, fc4{nullptr};
};

struct Options {
    std::string data_root{"./data"};
    int32_t batch_size{128};
    int32_t epochs{1000};
    double lr{0.001};
    double momentum{0.05};
    bool no_cuda{false};
    int32_t seed{1};
    int32_t test_batch_size{1000};
    int32_t log_interval{10};
};

}  // namespace
}  // namespace acrobot
}  // namespace multibody
}  // namespace examples
}  // namespace drake