#include <torch/torch.h>
#include <iostream>
#include <random>
#include <string>
#include <iterator>
#include <experimental/algorithm>

namespace drake {
namespace examples {
namespace multibody {
namespace {

struct Transition {
    VectorX<float> state, next_state;
    int64_t action{0}; 
    float reward{0.0};
    bool done{false};
};

struct Batch {
    torch::Tensor states, actions, next_states, rewards, non_final_states; 
};

template<class BidiIter >
BidiIter random_unique(BidiIter begin, BidiIter end, size_t num_random) {
    size_t left = std::distance(begin, end);
    while (num_random--) {
        BidiIter r = begin;
        std::advance(r, rand()%left);
        std::swap(*begin, *r);
        ++begin;
        --left;
    }
    return begin;
}

template<class Container >
Container random_sample(Container big_container, size_t num_random) {
    size_t left = std::distance(big_container.begin(), big_container.end());
    std::random_device rd;
    std::mt19937 e2(rd());
    std::uniform_real_distribution<> dist(0, left-1);
    Container small_container;
    for(int i=0; i<num_random; i++){
        int sample = int(dist(e2)); 
        small_container.push_back(big_container[sample]);
    }
    return small_container;
}

template <typename I>
I random_element(I begin, I end)
{
    const unsigned long n = std::distance(begin, end);
    const unsigned long divisor = (RAND_MAX) / n;

    unsigned long k;
    do { k = std::rand() / divisor; } while (k >= n);

    std::advance(begin, k);
    return begin;
}



class ReplayMemory
{
private:
    std::vector<Transition> memory; 
    const int capacity_;
    int position = 0;
public:
    ReplayMemory(int capacity) : capacity_(capacity) {
        position = 0;
    }
    virtual ~ReplayMemory(){};
    void Push(Transition transition){
        if(transition.action > 1 || transition.action < 0){
            return; 
        }
        if(memory.size() < capacity_){
            memory.push_back(transition);
        } else {
            memory[position] = transition;   
        }
        position = (position+1) % capacity_; 
        assert(position >= 0);
        assert(position < capacity_); 
    }
    int size(){
        return memory.size();
    }
    Batch Sample(int batch_size){
        // batch.state = torch::from_blob(batch.states, {options.batch_size, state_size})
        // batch.action = torch::from_blob(batch.actions, {options.batch_size, action_size})
        Batch out; 
        if(this->size() < batch_size){
            std::cout << "Error! should not ask for a batch if you do not have enough elements\n";
            return out; 
        }
        std::vector<Transition> transitions; // of size options.batch_size
        // // std::experimental::sample(memory.begin(), memory.end(), std::back_inserter(transitions), 
        // //         batch_size, std::mt19937{std::random_device{}()} );

        // random_unique(memory.begin(), memory.end(), batch_size);
        for(int i=0; i<batch_size; ++i) {
            auto iter = random_element(memory.begin(), memory.end() );
            transitions.push_back(*iter);
            // transitions.push_back(memory[i]);
        }

        // transitions = random_sample(memory, batch_size);

        int state_size = transitions.back().state.size();
        std::vector<float> states; //(batch_size * state_size); // make into a vector batch X size
        std::vector<int64_t> actions; 
        std::vector<float> next_states; //(batch_size * state_size); 
        std::vector<float> rewards;
        std::vector<float> non_final_states;
        for(auto &transition : transitions){
            for(int i=0; i<state_size; i++){
                states.push_back(transition.state(i));
            }
            
            actions.push_back(int64_t(transition.action));
            // std::cout << int64_t(transition.action) << std::endl; 
            for(int i=0; i<state_size; i++){
                next_states.push_back(transition.next_state(i));
            }
            
            if(transition.done){
                non_final_states.push_back(0.0);
                rewards.push_back(0.0);
            } else {
                non_final_states.push_back(1.0);
                rewards.push_back(float(transition.reward));
            }

            // if(rewards.back() < 0){
            //     std::string test; 
            //     std::cout << "WTF?? waiting for input" << std::endl;
            //     std::cin >> test; 
            // }
            
        }
        std::cout << "end of memory sample." << std::endl;
        // std::cout << "states size:" << states.size() << std::endl; 
        out.states = at::tensor(states, at::TensorOptions().dtype(torch::kFloat32).is_variable(true)).reshape({batch_size, state_size}); 
        std::cout << "states size: " << out.states.size(0) << ", "
                << out.states.size(1) << std::endl;
        // std::cout << "actions size:" << actions.size() << std::endl; 
        out.actions = at::tensor(actions, at::TensorOptions().dtype(torch::kLong).is_variable(true)).reshape({batch_size, 1});
        std::cout << "actions size: " << out.actions.size(0) << ", "
                << out.actions.size(1) << std::endl;
        out.next_states = at::tensor(next_states, at::TensorOptions().dtype(torch::kFloat32).is_variable(true)).reshape({batch_size, state_size}); 
        std::cout << "next_states size: " << out.next_states.size(0) << ", "
                << out.next_states.size(1) << std::endl;
        out.rewards = at::tensor(rewards, at::TensorOptions().dtype(torch::kFloat32).is_variable(true)).reshape({batch_size, 1}); 
        std::cout << "rewards size: " << out.rewards.size(0) << ", "
                << out.rewards.size(1) << std::endl;
        out.non_final_states = at::tensor(non_final_states, at::TensorOptions().dtype(torch::kFloat32).is_variable(true)).reshape({batch_size, 1}); 
        std::cout << "non_final_states size: " << out.non_final_states.size(0) << ", "
                << out.non_final_states.size(1) << std::endl;

        return out;
    }
};

}  // namespace
}  // namespace multibody
}  // namespace examples
}  // namespace drake