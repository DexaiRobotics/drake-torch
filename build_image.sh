#!/bin/bash

set -eufo pipefail

# parse arguments
BUILD_TYPE="cpu"
BUILD_CHANNEL="nightly"
USE_CACHE=true
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
    --nocache)
      USE_CACHE=false
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
  if [[ $BUILD_CHANNEL == 'stable' ]]; then
    BASE_IMAGE="ubuntu:bionic"
  else
    BASE_IMAGE="ubuntu:focal"
  fi
  TAG="dexai2/drake-torch:cpu"
else
  if [[ $BUILD_CHANNEL == 'stable' ]]; then
    BASE_IMAGE="nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04"
  else
    BASE_IMAGE="nvidia/cuda:11.0-devel-ubuntu20.04"
  fi
  TAG="dexai2/drake-torch:cuda"
fi

declare -a ARGS=(
  -f drake-torch.dockerfile
  --build-arg BUILD_TYPE=$BUILD_TYPE
  --build-arg BASE_IMAGE=$BASE_IMAGE
  --build-arg BUILD_CHANNEL=$BUILD_CHANNEL
  --cpuset-cpus "0-$LASTCORE"
  -t $TAG
)

echo "Building drake-torch image"
echo "Build type: $BUILD_TYPE"
echo "Channel: $BUILD_CHANNEL"
echo "Base image: $BASE_IMAGE"

if [[$USE_CACHE == false]]; then
  ARGS+=( --no-cache )
  echo "Cache disabled"
fi
echo "build args: ${ARGS[@]}"

docker build "${ARGS[@]}" . > /dev/stdout
