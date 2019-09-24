#!/bin/bash
publish_bionic () {
    date_string=`date +"%Y%m%d"`
    bionic_sha=$(docker images | grep "^drake-torch[[:space:]]*bionic" | awk '{print $3}')
    if [[ -z $date_string || -z $bionic_sha ]]; then
        echo "date $date_string or sha $bionic_sha is empty"
    else
        echo "tagging $bionic_sha as ubuntu/bionic_$date_string" 
        docker tag $bionic_sha dexai2/drake-torch:bionic_$date_string
        docker tag $bionic_sha dexai2/drake-torch:bionic_latest
        docker push dexai2/drake-torch:bionic_$date_string
        docker push dexai2/drake-torch:bionic_latest
    fi
}
publish_cuda () {
    date_string=`date +"%Y%m%d"`
    cuda_sha=$(docker images | grep "^drake-torch[[:space:]]*cuda" | awk '{print $3}')
    if [[ -z $date_string || -z $cuda_sha ]]; then
        echo "date $date_string or sha $cuda_sha is empty"
    else
        echo "tagging $cuda_sha as dexai2/drake-torch:cuda_$date_string" 
        docker tag $cuda_sha dexai2/drake-torch:cuda_$date_string
        docker tag $cuda_sha dexai2/drake-torch:cuda_latest
        docker push dexai2/drake-torch:cuda_$date_string
        docker push dexai2/drake-torch:cuda_latest
    fi
}
if [[ $# -eq 0 ]]; then
    echo "no arguments supplied, defaulting to publishing both bionic and cuda"
    publish_bionic
    publish_cuda
elif [[ $* == *--bionic* ]]; then
    echo "Ubuntu Bionic specified:"
    publish_bionic
elif [[ $* == *--cuda* ]]; then
    echo "CUDA specified:"
    publish_cuda
else
    echo "need to specify --cuda --ubuntu (or no arguments, defaults to both ubuntu/bionic and cuda)"
fi

