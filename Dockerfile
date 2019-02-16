FROM ubuntu:bionic

WORKDIR /root/drake-torch
COPY src/drake/setup/ubuntu setup/ubuntu
COPY scripts scripts

# setup timezone
RUN set -eux && export DEBIAN_FRONTEND=noninteractive \
    && echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && apt-get install -q -y tzdata \
    && rm -rf /var/lib/apt/lists/*

# install cmake 3.13.4, based on https://ompl.kavrakilab.org/install-ompl-ubuntu.sh:
RUN apt-get update -qq && apt-get purge -qy cmake \
    && apt-get install -qy wget \
    && rm -rf /var/lib/apt/lists/*
RUN wget https://cmake.org/files/v3.13/cmake-3.13.4-Linux-x86_64.tar.gz
RUN tar -xzf cmake-3.13.4-Linux-x86_64.tar.gz
RUN cp -r cmake-3.13.4-Linux-x86_64/bin /usr/
RUN cp -r cmake-3.13.4-Linux-x86_64/share /usr/
RUN cp -r cmake-3.13.4-Linux-x86_64/doc /usr/share/
RUN cp -r cmake-3.13.4-Linux-x86_64/man /usr/share/

RUN set -eux \
  && export DEBIAN_FRONTEND=noninteractive \
  && yes | setup/ubuntu/install_prereqs.sh \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -q -y python3-dev python3-pip \
    python3-virtualenv \
    libgtest-dev libgflags-dev \
    x11vnc xvfb wget curl unzip xz-utils gzip apt-utils \
    python2.7 python2.7-dev \
    python-empy python-nose python-numpy \
    python-pip python-tk python-yaml \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir ~/gtest && cd ~/gtest && cmake /usr/src/gtest && make \
    && cp *.a /usr/local/lib

RUN mkdir -p /opt \
    && curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt
    # && tar -xzC drake-latest-bionic.tar.gz \
    # && mv drake /opt/drake

RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install --upgrade cython
RUN python3 -m pip install --upgrade defusedxml netifaces setuptools wheel virtualenv
# Install pip packages that depend on cython or setuptools already being installed
RUN python3 -m pip install --upgrade msgpack nose2 numpy pyside2 rospkg
# Install pytorch dependencies
RUN python3 -m pip install --upgrade numpy mkl mkl-include cmake cffi typing 

RUN python -m pip install --upgrade pip
RUN python -m pip install --upgrade cython
RUN python -m pip install --upgrade defusedxml netifaces setuptools wheel virtualenv
# Install pip packages that depend on cython or setuptools already being installed
RUN python -m pip install --upgrade msgpack nose2 numpy pyside2 rospkg
# Install pytorch dependencies
RUN python -m pip install --upgrade numpy mkl mkl-include cmake cffi typing 
# pyyaml
RUN python -m pip install --upgrade visdom

RUN cd /root/drake-torch && git clone https://github.com/DexaiRobotics/pytorch.git \
    && cd pytorch && git submodule update --init --recursive
RUN cd /root/drake-torch/pytorch/tools && python3 build_libtorch.py

ENTRYPOINT ["scripts/cartpole_entrypoint.sh"]
