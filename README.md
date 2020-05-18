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
(1) tag the new version both as `<type>_latest` and as `<type>_<date>` in `YYYYMMDD` format where `<type>` is `cuda` or `cpu`

`docker tag <commit> dexai2/drake-torch:cuda_latest`

and

`docker tag <commit> dexai2/drake-torch:cuda_<date>`

or

`docker tag <commit> dexai2/drake-torch:cpu_latest`

and

`docker tag <commit> dexai2/drake-torch:cpu_<date>`

then, publish to docker hub

(2) login to docker hub with your credentials

`docker login --username=yourhubusername`

(3) push the latest version

`docker push dexai2/drake-torch:cuda_latest`

and

`docker push dexai2/drake-torch:cuda_<date>`
