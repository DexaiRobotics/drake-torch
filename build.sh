#!/bin/bash
build_bionic () {
    echo "building Ubuntu/bionic"
    docker build -f drake-torch.dockerfile --build-arg BASE_IMAGE=ubuntu:bionic -t drake-torch:bionic .
}
build_cuda () {
    echo "building nvidia/cuda:10.0-devel"
    docker build -f drake-torch.dockerfile --build-arg BASE_IMAGE=nvidia/cuda:10.0-devel -t drake-torch:cuda .
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

