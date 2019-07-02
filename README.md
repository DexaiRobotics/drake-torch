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
`docker tag <commit> dmsj/drake-torch:cuda_latest`
or
`docker tag <commit> dmsj/drake-torch:bionic_latest`
then, publish to docker hub
(1) login to docker hub with your credentials
`docker login --username=yourhubusername`
(2) push the latest version
`docker push dmsj/drake-torch:cuda_latest`
