#!/bin/bash

# we don't publish nightly build for now, which rarely succeeds anyway
# tag the successful stable channel builds by the date
# dexai2/drake-torch:cpu  -> dexai2/drake-torch:cpu_YYMMDD
#                         -> dexai2/drake-torch:cpu_latest
# dexai2/drake-torch:cuda -> dexai2/drake-torch:cuda_YYMMDD
#                         -> dexai2/drake-torch:cuda_latest

REPO_STR=dexai2/drake-torch
SUFFIX_DATE=$(date +"%Y%m%d")

tag_and_push() {
    BUILD_TYPE=$1
    SUFFIX=$2
    echo "tagging and pushing image, build type $BUILD_TYPE, suffix $SUFFIX"
    docker tag $REPO_STR:$BUILD_TYPE $REPO_STR:"${BUILD_TYPE}_${SUFFIX}"
}


tag_and_push cpu $SUFFIX_DATE
tag_and_push cpu latest
tag_and_push cuda $SUFFIX_DATE
tag_and_push cuda latest
