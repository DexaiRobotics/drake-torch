# drake-torch
Example demonstrating pytorch c++ integration with drake

# Installation
This repo provides two Dockerfiles, for CPU and GPU versions of pytorch.

The CPU version uses standard, vanilla Docker; while the GPU version requires NVIDIA-docker. 

## NVIDIA-docker
The host machine needs to have the same nvidia-driver and (possibly not?) CUDA version as the docker image. 
The current version is built based on `nvidia-driver-410.48` and `cuda-10-0`. 
### installing nvidia-driver
### installing CUDA 10.0
### installing cuDNN
### installing nvidia-docker

# publishing drake-torch to docker hub
(1) tag the new version both as `<type>_latest` and as `<type>_<date>` in `YYYYMMDD` format where `<type>` is `cuda` or `bionic`

`docker tag <commit> dmsj/drake-torch:cuda_latest`

and

`docker tag <commit> dmsj/drake-torch:cuda_<date>`

or

`docker tag <commit> dmsj/drake-torch:bionic_latest`

and

`docker tag <commit> dmsj/drake-torch:bionic_<date>`

then, publish to docker hub

(2) login to docker hub with your credentials

`docker login --username=yourhubusername`

(3) push the latest version

`docker push dmsj/drake-torch:cuda_latest`

and

`docker push dmsj/drake-torch:cuda_<date>`
