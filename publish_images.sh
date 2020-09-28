#!/bin/bash

# we don't publish nightly build for now, which rarely succeeds anyway
# tag the successful stable channel builds by the date
# dexai2/drake-torch:cpu  -> dexai2/drake-torch:cpu_YYMMDD
#                         -> dexai2/drake-torch:cpu_latest
# dexai2/drake-torch:cuda -> dexai2/drake-torch:cuda_YYMMDD
#                         -> dexai2/drake-torch:cuda_latest


REPOSITORY=drake-torch
SUFFIX_DATE=$(date +"%Y%m%d")

OPT_CPU=true
OPT_CUDA=true

# Parse any arguments.
while (( $# )); do
  case "$1" in
    --cpu)
      OPT_CUDA=false
      shift 1
      ;;
    --cuda)
      OPT_CPU=false
      shift 1
      ;;
    -r|--repo)
      shift 1
      REPOSITORY="$1"
      shift 1
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported options
      echo "Error: Unsupported option $1" >&2
      exit 1
      ;;
    *) # positional arg -- in this case, path to src directory
      SRC_PATH="$1"
      shift
      ;;
  esac
done

REPO_STR="dexai2/${REPOSITORY}"

tag_and_push() {
    BUILD_TYPE=$1
    SUFFIX=$2
    echo "tagging and pushing image to dexai2/$REPOSITORY, build type $BUILD_TYPE, suffix $SUFFIX"
    CURRENT_TAG=$REPO_STR:$BUILD_TYPE
    NEW_TAG=$REPO_STR:"${BUILD_TYPE}_${SUFFIX}"
    docker tag $CURRENT_TAG $NEW_TAG
    docker push $NEW_TAG
}

# suspend publishing until 20.04 upgrade is done and working
tag_and_push cpu $SUFFIX_DATE
# tag_and_push cpu latest
tag_and_push cuda $SUFFIX_DATE
# tag_and_push cuda latest
