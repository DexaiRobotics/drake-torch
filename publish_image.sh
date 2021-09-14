#!/bin/bash

# we don't publish nightly build for now, which rarely succeeds anyway
# tag the successful stable channel builds by the date
# dexai2/drake-torch:cpu  -> dexai2/drake-torch:cpu_YYMMDD
#                         -> dexai2/drake-torch:cpu_latest
# dexai2/drake-torch:cuda -> dexai2/drake-torch:cuda_YYMMDD
#                         -> dexai2/drake-torch:cuda_latest


SUFFIX_DATE=$(date +"%Y%m%d")

BUILD_TYPE=cuda
BUILD_CHANNEL=nightly
OPT_ROS=false
LIBTORCH=false
REPO_NAME="drake-pytorch"
# Parse any arguments.
while (( $# )); do
  case "$1" in
    --cpu)
      BUILD_TYPE=cpu
      shift 1
      ;;
    --cuda)
      BUILD_TYPE=cuda
      shift 1
      ;;
    --libtorch)
      LIBTORCH=true
      REPO_NAME="drake-torch"
      shift 1
      ;;
    --stable)
      BUILD_CHANNEL=stable
      shift 1
      ;;
    --nightly)
      BUILD_CHANNEL=nightly
      shift 1
      ;;
    --ros)
      OPT_ROS=true
      shift 1
      ;;
    -*|--*=) # unsupported options
      echo "Error: Unsupported option $1" >&2
      exit 1
      ;;
    *) # positional arg
      echo "Error: Unsupported option $1" >&2
      exit 1
      ;;
  esac
done

REPO_STR="dexai2/${REPO_NAME}"

tag_and_push() {
  CURRENT_TAG=$1
  SUFFIX=$2
  NEW_TAG="${CURRENT_TAG}-${SUFFIX}"
  echo "tagging and pushing, current tag: ${CURRENT_TAG}, new tag: ${NEW_TAG}"
  docker tag $CURRENT_TAG $NEW_TAG
  docker push $NEW_TAG > /dev/null
}

if [[ $OPT_ROS == true ]]; then
  CURRENT_TAG="${REPO_STR}:${BUILD_TYPE}-${BUILD_CHANNEL}-ros"
else
  CURRENT_TAG="${REPO_STR}:${BUILD_TYPE}-${BUILD_CHANNEL}"
fi

# suspend publishing until 20.04 upgrade is done and working
tag_and_push $CURRENT_TAG $SUFFIX_DATE
tag_and_push $CURRENT_TAG latest
