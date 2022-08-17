#!/bin/bash

set -eufo pipefail

BUILD_TYPE="cuda"
BUILD_CHANNEL="nightly"
LIBTORCH=false
REPO_NAME="drake-pytorch"
BUILD_ROS=false
USE_CACHE=true
while (( $# )); do
  case "$1" in
    --cuda)
      BUILD_TYPE="cuda"
      shift 1
      ;;
    --libtorch)
      LIBTORCH=true
      REPO_NAME="drake-torch"
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
    --ros)
      BUILD_ROS=true
      shift 1
      ;;
    *|-*|--*=) # unsupported options
      echo "Error: Unsupported option $1" >&2
      exit 1
  esac
done

NUMTHREADS=$(grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}')
LASTCORE=$((NUMTHREADS - 1))
echo "Using all $NUMTHREADS cores: 0-$LASTCORE for the --cpuset-cpus option"

if [[ $BUILD_ROS = true ]]; then
  if [[ $BUILD_CHANNEL == 'stable' ]]; then
    DOCKERFILE="drake-torch-noetic.dockerfile"
    if [[ $BUILD_TYPE == "cpu" ]]; then
      BASE_IMAGE="dexai2/$REPO_NAME:cpu-stable"
    else
      BASE_IMAGE="dexai2/$REPO_NAME:cuda-stable"
    fi
  else
    DOCKERFILE="drake-torch-noetic.dockerfile"
    if [[ $BUILD_TYPE == "cpu" ]]; then
      BASE_IMAGE="dexai2/$REPO_NAME:cpu-nightly"
    else
      BASE_IMAGE="dexai2/$REPO_NAME:cuda-nightly"
    fi
  fi
  TAG="${BASE_IMAGE}-ros"
else
  DOCKERFILE="drake-torch.dockerfile"
  if [[ $BUILD_TYPE == "cpu" ]]; then
    if [[ $BUILD_CHANNEL == 'stable' ]]; then
      BASE_IMAGE="ubuntu:20.04"
    else
      BASE_IMAGE="ubuntu:22.04"
    fi
  else
    if [[ $BUILD_CHANNEL == 'stable' ]]; then
      BASE_IMAGE="nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu20.04"
    else
      BASE_IMAGE="nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu22.04"
    fi
  fi
  TAG="dexai2/$REPO_NAME:${BUILD_TYPE}-${BUILD_CHANNEL}"
fi

declare -a ARGS=(
  -f "$DOCKERFILE"
  --build-arg BUILD_TYPE="$BUILD_TYPE"
  --build-arg LIBTORCH="$LIBTORCH"
  --build-arg BASE_IMAGE="$BASE_IMAGE"
  --build-arg BUILD_CHANNEL="$BUILD_CHANNEL"
  --cpuset-cpus "0-$LASTCORE"
  -t "$TAG"
)

if [[ $USE_CACHE == false ]]; then
  ARGS+=( --no-cache )
  echo "Cache disabled"
fi

echo "Building image, to be tagged as: $TAG"
echo "Build type: $BUILD_TYPE"
echo "Libtorch: $LIBTORCH"
echo "Channel: $BUILD_CHANNEL"
echo "Base image: $BASE_IMAGE"
echo "Build ROS: $BUILD_ROS"
echo "build args: ${ARGS[@]}"

docker build "${ARGS[@]}" . > /dev/stdout
