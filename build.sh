#!/bin/bash

# parse arguments
BUILD_TYPE="cpu"
BUILD_CHANNEL="nightly"
while (( $# )); do
  case "$1" in
    --cuda)
      BUILD_TYPE="cuda"
      shift 1
      ;;
    --cpu)
      BUILD_TYPE="cpu"
      shift 1
      ;;
    --stable)
      BUILD_CHANNEL="stable"
      shift 1
      ;;
    --nightly)
      BUILD_CHANNEL="nightly"
      shift 1
      ;;
    -*|--*=) # unsupported options
      echo "Error: Unsupported option $1" >&2
      exit 1
      ;;
    *) # positional arg -- in this case, path to src directory
      DEVICE_TYPE="$1"
      shift
      ;;
  esac
done

NUMTHREADS=$(grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}')
LASTCORE=$((NUMTHREADS - 1))
echo "Using all $NUMTHREADS cores: 0-$LASTCORE for the --cpuset-cpus option"

if [[ $BUILD_TYPE == "cpu" ]]; then
  BASE_IMAGE="ubuntu:bionic"
  TAG="dexai2/drake-torch:cpu"
else
  cuda_version=10.1
  cudnn_version=7
  ubuntu=18.04
  BASE_IMAGE="nvidia/cuda:${cuda_version}-cudnn${cudnn_version}-devel-ubuntu${ubuntu}"
  echo "building from base image: $BASE_IMAGE" > /dev/stderr
  TAG="dexai2/drake-torch:cuda"
fi

echo "building drake-torch image, build type: $BUILD_TYPE, base image: $BASE_IMAGE, channel: $BUILD_CHANNEL"
docker build -f drake-torch.dockerfile --no-cache --build-arg BUILD_TYPE=$BUILD_TYPE --build-arg BASE_IMAGE=$BASE_IMAGE --build-arg BUILD_CHANNEL=$BUILD_CHANNEL -t $TAG --cpuset-cpus "0-$LASTCORE" . > /dev/stderr
