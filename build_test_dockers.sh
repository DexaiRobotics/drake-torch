#!/bin/bash
build_cpu () {
    echo "building drake-torch:cpu_test"
    docker build --no-cache -f test_python.dockerfile --build-arg BASE_IMAGE=dexai2/drake-torch:cpu --cpuset-cpus 0-4 .
}
build_cuda () {
    echo "building drake-torch:cuda_test"
    docker build --no-cache -f test_python.dockerfile --build-arg BASE_IMAGE=dexai2/drake-torch:cuda --cpuset-cpus 0-4 .
}
if [[ $# -eq 0 ]]; then
    echo "no arguments supplied, defaulting to both cpu and cuda:"
    build_cpu
    build_cuda
elif [[ $* == *--cpu* || $* == *--bionic* ]]; then
    echo "Ubuntu/cpu specified:"
    build_cpu
elif [[ $* == *--cuda* ]]; then
    echo "CUDA specified:"
    build_cuda
else
    echo "need to specify --cuda --ubuntu (or no arguments, defaults to both drake-torch:cpu and drake-torch:cuda)"
fi
