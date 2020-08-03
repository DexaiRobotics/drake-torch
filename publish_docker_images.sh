#!/bin/bash

# we don't publish nightly build for now, which rarely succeeds anyway
# tag the successful stable channel builds by the date
# dexai2/drake-torch:cpu  -> dexai2/drake-torch:cpu_YYMMDD
#                         -> dexai2/drake-torch:cpu_latest
# dexai2/drake-torch:cuda -> dexai2/drake-torch:cuda_YYMMDD
#                         -> dexai2/drake-torch:cuda_latest

repo_str=dexai2/drake-torch
suffix_date=$(date +"%Y%m%d")

tag_and_push() {
    BUILD_TYPE=$1
    SUFFIX=$2
    echo "tagging and pushing image, build type $BUILD_TYPE, suffix $SUFFIX"
    docker tag repo_str:$BUILD_TYPE repo_str:"${BUILD_TYPE}_${SUFFIX}"
}


tag_and_push cpu date_string
tag_and_push cpu latest
tag_and_push cuda date_string
tag_and_push cuda latest
