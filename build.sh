#!/bin/bash
build_cpu () {
    echo "building Ubuntu/cpu" > /dev/stderr
    docker build -f drake-torch.dockerfile --no-cache --build-arg BASE_IMAGE=ubuntu:bionic --build-arg BUILD_TYPE=cpu -t drake-torch:cpu --cpuset-cpus 0-4 . > /dev/stderr
    build_result=$? # debugging to see if function does the right thing
    # echo "cpu_build_result = ${build_result}" > /dev/stderr
    echo "${build_result}"
}
build_cuda () {
    cuda_version=10.1
    cudnn_version=7
    ubuntu=18.04
    # --no-cache
    echo "building nvidia/cuda:${cuda_version}-cudnn${cudnn_version}-devel-ubuntu${ubuntu}" > /dev/stderr
    docker build -f drake-torch.dockerfile --no-cache --build-arg BUILD_TYPE=cuda --build-arg BASE_IMAGE=nvidia/cuda:${cuda_version}-cudnn${cudnn_version}-devel-ubuntu${ubuntu} -t drake-torch:cuda --cpuset-cpus 0-4 . > /dev/stderr
    build_result=$?
    echo "${build_result}"
}
if [[ $# -eq 0 ]]; then
    echo "no arguments supplied, defaulting to:"
    result=$(build_cpu)
    echo "build_cpu returned: ${result}"
    exit $result
elif [[ $* == *--cpu* || $* == *--bionic* ]]; then
    echo "Ubuntu/cpu specified:"
    result=$(build_cpu)
    echo "build_cpu returned: ${result}"
    exit $result
elif [[ $* == *--cuda* ]]; then
    echo "CUDA specified:"
    result=$(build_cuda)
    echo "build_cuda returned ${result}"
    exit $result
else
    echo "need to specify --cuda --ubuntu (or no arguments, defaults to ubuntu/cpu)"
    exit 1
fi
