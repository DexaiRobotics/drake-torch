# drake-torch

This repo provides an example of ingegrating both `drake` and `pytorch` in docker images, with Nvidia's CUDA images or vanilla Ubuntu images being the base image.

The multi-stage `Jenkinsfile`s specify the build process for CUDA and CPU images. To run these pipelines in Jenkins and produce CUDA images, The host machine needs to have NVidia driver and `nvidia-docker2` installed.

Additional ROS packages are included in the `-ros` images.

Images with Python packages and C++ `libtorch` are published at: https://hub.docker.com/repository/docker/dexai2/drake-torch/.
Images with Python packages only and no C++ `libtorch` are published at: https://hub.docker.com/repository/docker/dexai2/drake-pytorch/.
