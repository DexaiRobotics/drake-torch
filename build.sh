#!/bin/bash
build_bionic () {
    echo "building Ubuntu/bionic"
    docker build -f drake-torch.dockerfile --build-arg BASE_IMAGE=ubuntu:bionic -t drake-torch:bionic --cpuset-cpus 0-4 .
}
build_cuda () {
    cuda_version=10.0
    cudnn_version=7
    ubuntu=18.04
    echo "building nvidia/cuda:${cuda_version}-cudnn${cudnn_version}-devel-ubuntu${ubuntu}"
    docker build -f drake-torch.dockerfile --build-arg BASE_IMAGE=nvidia/cuda:${cuda_version}-cudnn${cudnn_version}-devel-ubuntu${ubuntu} -t drake-torch:cuda --cpuset-cpus 0-4 .
}
if [[ $# -eq 0 ]]; then
    echo "no arguments supplied, defaulting to:"
    build_bionic
elif [[ $* == *--bionic* ]]; then
    echo "Ubuntu/bionic specified:"
    build_bionic
elif [[ $* == *--cuda* ]]; then
    echo "CUDA specified:"
    build_cuda
else
    echo "need to specify --cuda --ubuntu (or no arguments, defaults to ubuntu/bionic)"
fi
