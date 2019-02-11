#!/bin/bash

# if [ "$(whoami)" == "root" ]; then
#   echo "running as root, please run as user you want to have stuff installed as"
#   exit 1
# fi

# set build environment for StuffGetter
# export TORCH_INCLUDE_DIR="/opt/libtorch/lib/include/torch/csrc/api/include"
export TORCH_INCLUDE_DIR="/opt/libtorch/csrc/api/include"
export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/include/"
export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/include/torch/csrc/api/include/"
export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/lib/include/"
export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/"
export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;$PWD/../pytorch"


export TORCH_LIBRARIES="/opt/libtorch/lib/libtorch.so"
export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libc10.so"
export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2.so"
export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2_module_test_dynamic.so"
export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libonnxifi_dummy.so"
# export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libshm.so"
# export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libtorch_python.so"
# export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2_observers.so"


export STUFFGETTER_DIR="$PWD"
cd "/usr/local/cuda-10.0/extras/demo_suite"
./deviceQuery  | grep "Result = PASS"
greprc=$?
if [[ $greprc -eq 0 ]] ; then
    echo "Cuda Samples installed and GPU found"
    echo "you can also check usage and temperature of gpus with nvidia-smi"
    cd $STUFFGETTER_DIR
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libonnxifi.so"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;libnvrtc.so;libcuda.so"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libc10_cuda.so"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2_detectron_ops_gpu.so"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2_gpu.so"

else
    if [[ $greprc -eq 1 ]] ; then
        echo "Cuda Samples not installed, continuing..."
        cd $STUFFGETTER_DIR
    else
        echo "Some sort of error, exiting..."
        exit 1
    fi
fi

export DRAKE_BUILD_DIR="/opt/drake"
## ENV VAR for pybind11 needed on Ubunu (or at least alfred):
export PYBIND_INCLUDE_DIR="/opt/drake/include/pybind11"
export DRACULA_SOURCE_PATH="$PWD/../dracula"
export DRACULA_BUILD_PATH="$DRACULA_SOURCE_PATH/build"
export DRACULA_INCLUDE_DIR="$DRACULA_SOURCE_PATH/dracula/include"
export DRACULA_LIBRARIES="$DRACULA_BUILD_PATH/dracula/libdracula.so"

export ROBOT_SOURCE_PATH="$PWD/../robot_interface"
export ROBOT_BUILD_PATH="$ROBOT_SOURCE_PATH/build"
export ROBOT_INCLUDE_DIR="$ROBOT_SOURCE_PATH/include"
export ROBOT_LIBRARIES="$ROBOT_BUILD_PATH/librobot_interface.so"

export JSON_INCLUDE_DIR="$PWD/externals/json/include"
export UUID_BASE_DIR="$DRACULA_SOURCE_PATH/externals/crossguid"
export UUID_INCLUDE_DIR="$UUID_BASE_DIR/include"
export UUID_LIBRARIES="$UUID_BASE_DIR/build/libcrossguid.a"
export GITVERSION_CMAKE="$PWD/externals/gitversion/cmake.cmake"

# This is the default location of *installed* headers on both Ubuntu 16.04 and Mac OSX
export OMPL_INCLUDE_DIR="/usr/local/include"

export CTPL_INCLUDE_DIR="$DRACULA_SOURCE_PATH/externals/CTPL"

LOCAL_PYTHON=`which python`
LOCAL_PYTHON_BIN_DIR=`dirname $LOCAL_PYTHON`
export LOCAL_PYTHON_PATH=`dirname $LOCAL_PYTHON_BIN_DIR`
echo "LOCAL_PYTHON_PATH: $LOCAL_PYTHON_PATH"

if [ "$(uname)" == "Darwin" ]; then
    export DRACULA_LIBRARIES="$DRACULA_BUILD_PATH/dracula/libdracula.dylib"
    export ROBOT_LIBRARIES="$ROBOT_BUILD_PATH/librobot_interface.dylib"
    export OMPL_DIR="/usr/local/lib"
    export OMPL_INCLUDE_DIR="$OMPL_DIR/include"
    export UUID_LIBRARIES="$UUID_BASE_DIR/build/libcrossguid.a" # ;$UUID_BASE_DIR/build/libcrossguid.dylib"

    export TORCH_LIB_DIR="/opt/libtorch/share/cmake/Torch;/opt/libtorch/share/cmake/Caffe2;"
    export TORCH_INCLUDE_DIR="/opt/libtorch/include/torch/csrc/api/include"
    export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/include/"
    export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/csrc/api/include"
    export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;/opt/libtorch/lib/include/"
    export TORCH_INCLUDE_DIR="$TORCH_INCLUDE_DIR;$PWD/../pytorch/"

    export TORCH_LIBRARIES="/opt/libtorch/lib/libtorch.dylib;/opt/libtorch/lib/libc10.dylib;/opt/libtorch/lib/libcaffe2.dylib"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2_module_test_dynamic.dylib"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libonnxifi_dummy.dylib"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libshm.dylib"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libtorch_python.dylib"
    export TORCH_LIBRARIES="$TORCH_LIBRARIES;/opt/libtorch/lib/libcaffe2_observers.dylib"
fi
