#!/bin/bash
# build & run the pytorch MNIST example

cd mnist
mkdir -p build
cd build
cmake -DCMAKE_PREFIX_PATH=/opt/libtorch ..
make
./mnist
cd ../..
