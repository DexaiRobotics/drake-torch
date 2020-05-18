#!/bin/bash
publish_cpu_date () {
    date_string=`date +"%Y%m%d"`
    cpu_sha=$(docker images | grep "^drake-torch[[:space:]]*cpu " | awk '{print $3}')
    if [[ -z $date_string || -z $cpu_sha ]]; then
        echo "date $date_string or sha $cpu_sha is empty"
    else
        echo "tagging $cpu_sha as dexai2/drake-torch:cpu_$date_string"
        docker tag $cpu_sha dexai2/drake-torch:cpu_$date_string
        # docker push dexai2/drake-torch:cpu_$date_string
    fi
}
publish_cpu_latest () {
    cpu_sha=$(docker images | grep "^drake-torch[[:space:]]*cpu " | awk '{print $3}')
    if [[ -z $cpu_sha ]]; then
        echo "sha $cpu_sha is empty"
    else
        docker tag $cpu_sha dexai2/drake-torch:cpu_latest
        docker push dexai2/drake-torch:cpu_latest
    fi
}
publish_cuda_date () {
    date_string=`date +"%Y%m%d"`
    cuda_sha=$(docker images | grep "^drake-torch[[:space:]]*cuda " | awk '{print $3}')
    if [[ -z $date_string || -z $cuda_sha ]]; then
        echo "date $date_string or sha $cuda_sha is empty"
    else
        echo "tagging $cuda_sha as dexai2/drake-torch:cuda_$date_string"
        docker tag $cuda_sha dexai2/drake-torch:cuda_$date_string
        # docker push dexai2/drake-torch:cuda_$date_string
    fi
}
publish_cuda_latest () {
    cuda_sha=$(docker images | grep "^drake-torch[[:space:]]*cuda " | awk '{print $3}')
    if [[ -z $cuda_sha ]]; then
        echo "sha $cuda_sha is empty"
    else
        docker tag $cuda_sha dexai2/drake-torch:cuda_latest
        docker push dexai2/drake-torch:cuda_latest
    fi
}
if [[ $# -eq 0 ]]; then
    echo "no arguments supplied, defaulting to publishing dated versions of cpu and cuda"
    publish_cpu_date
    publish_cuda_date
elif [[ $* == *--cpu* || $* == *--bionic* ]]; then
    echo "Ubuntu cpu specified, publishing dated version:"
    publish_cpu_date
    if [[ $* == *--latest* ]]; then
        publish_cpu_latest
    fi
elif [[ $* == *--cuda* ]]; then
    echo "CUDA specified, publishing dated version:"
    publish_cuda_date
    if [[ $* == *--latest* ]]; then
        publish_cuda_latest
    fi
elif [[ $* == *--latest* && ( $* != *--cuda* && $* != *--cpu* ) ]]; then
    echo "only --latest specified, publishing latest cpu and cuda version:"
    publish_cpu_date
    publish_cuda_date
    publish_cpu_latest
    publish_cuda_latest
else
    echo "need to specify --cuda --cpu (or no arguments, defaults to both cpu and cuda); add --latest to also update the latest tag"
fi
