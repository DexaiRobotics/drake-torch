Example usage of `drake` and `pytorch` via the `libtorch` c++ interface.

Try the MNIST cpp example which ships with `pytorch`
`./test_mnist.sh`
results in:
```shell
root@8ac6b8b20e0d:/src/examples# ./test_mnist.sh 
-- The C compiler identification is GNU 7.3.0
-- The CXX compiler identification is GNU 7.3.0
-- Check for working C compiler: /usr/bin/cc
-- Check for working C compiler: /usr/bin/cc -- works
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Detecting C compile features
-- Detecting C compile features - done
-- Check for working CXX compiler: /usr/bin/c++
-- Check for working CXX compiler: /usr/bin/c++ -- works
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Looking for pthread.h
-- Looking for pthread.h - found
-- Looking for pthread_create
-- Looking for pthread_create - not found
-- Looking for pthread_create in pthreads
-- Looking for pthread_create in pthreads - not found
-- Looking for pthread_create in pthread
-- Looking for pthread_create in pthread - found
-- Found Threads: TRUE  
-- Found torch: /opt/libtorch/lib/libtorch.so  
-- Downloading MNIST dataset
Downloading http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz ...
0% |################################################################| 100%
Unzipped /src/examples/mnist/build/data/train-images-idx3-ubyte.gz ...
Downloading http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz ...
0% |################################################################| 100%
Unzipped /src/examples/mnist/build/data/train-labels-idx1-ubyte.gz ...
Downloading http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz ...
0% |################################################################| 100%
Unzipped /src/examples/mnist/build/data/t10k-images-idx3-ubyte.gz ...
Downloading http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz ...
0% |################################################################| 100%
Unzipped /src/examples/mnist/build/data/t10k-labels-idx1-ubyte.gz ...
-- Configuring done
-- Generating done
-- Build files have been written to: /src/examples/mnist/build
Scanning dependencies of target mnist
[ 50%] Building CXX object CMakeFiles/mnist.dir/mnist.cpp.o
/src/examples/mnist/mnist.cpp: In instantiation of ‘void train(int32_t, Net&, c10::Device, DataLoader&, torch::optim::Optimizer&, size_t) [with DataLoader = torch::data::StatelessDataLoader<torch::data::datasets::MapDataset<torch::data::datasets::MapDataset<torch::data::datasets::MNIST, torch::data::transforms::Normalize<> >, torch::data::transforms::Stack<torch::data::Example<> > >, torch::data::samplers::SequentialSampler>; int32_t = int; size_t = long unsigned int]’:
/src/examples/mnist/mnist.cpp:151:77:   required from here
/src/examples/mnist/mnist.cpp:75:18: warning: format ‘%ld’ expects argument of type ‘long int’, but argument 2 has type ‘int32_t {aka int}’ [-Wformat=]
       std::printf(
       ~~~~~~~~~~~^
           "\rTrain Epoch: %ld [%5ld/%5ld] Loss: %.4f",
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
           epoch,
           ~~~~~~  
           batch_idx * batch.data.size(0),
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
           dataset_size,
           ~~~~~~~~~~~~~
           loss.template item<float>());
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[100%] Linking CXX executable mnist
[100%] Built target mnist
```
```shell
Training on CPU.
Train Epoch: 1 [59584/60000] Loss: 0.2237
Test set: Average loss: 0.2083 | Accuracy: 0.934
Train Epoch: 2 [59584/60000] Loss: 0.1839
Test set: Average loss: 0.1287 | Accuracy: 0.960
Train Epoch: 3 [59584/60000] Loss: 0.0973
Test set: Average loss: 0.1003 | Accuracy: 0.970
Train Epoch: 4 [59584/60000] Loss: 0.1225
Test set: Average loss: 0.0845 | Accuracy: 0.973
Train Epoch: 5 [59584/60000] Loss: 0.0735
Test set: Average loss: 0.0781 | Accuracy: 0.974
Train Epoch: 6 [59584/60000] Loss: 0.0648
Test set: Average loss: 0.0682 | Accuracy: 0.977
Train Epoch: 7 [59584/60000] Loss: 0.2047
Test set: Average loss: 0.0620 | Accuracy: 0.981
Train Epoch: 8 [59584/60000] Loss: 0.0808
Test set: Average loss: 0.0593 | Accuracy: 0.981
Train Epoch: 9 [59584/60000] Loss: 0.0522
Test set: Average loss: 0.0546 | Accuracy: 0.984
Train Epoch: 10 [59584/60000] Loss: 0.0867
Test set: Average loss: 0.0516 | Accuracy: 0.984
```