#FROM ubuntu:bionic
FROM nvidia/cuda:10.0-devel

WORKDIR /root

# setup timezone
RUN set -eux && export DEBIAN_FRONTEND=noninteractive \
    && echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && apt-get install -q -y tzdata \
    && rm -rf /var/lib/apt/lists/*

# install cmake 3.13.4, based on https://ompl.kavrakilab.org/install-ompl-ubuntu.sh:
RUN apt-get update -qq && apt-get purge -qy cmake \
    && apt-get install -qy wget git \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://cmake.org/files/v3.14/cmake-3.14.4-Linux-x86_64.tar.gz \
    && tar -xzf cmake-3.14.4-Linux-x86_64.tar.gz \
    && cp -r cmake-3.14.4-Linux-x86_64/bin /usr/ \
    && cp -r cmake-3.14.4-Linux-x86_64/share /usr/ \
    && cp -r cmake-3.14.4-Linux-x86_64/doc /usr/share/ \
    && cp -r cmake-3.14.4-Linux-x86_64/man /usr/share/ \
    && cd $HOME && rm -rf  cmake-3.14.4-Linux-x86_64.tar.gz \
    && rm -rf cmake-3.14.4-Linux-x86_64

RUN apt-get update && apt-get install -q -y python3-dev python3-pip \
    python3-virtualenv \
    libgtest-dev libgflags-dev \
    x11vnc xvfb wget curl unzip xz-utils gzip apt-utils \
    python3-empy python3-nose python3-numpy \
    python3-pip python3-tk python3-yaml \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && mkdir -p /opt \
    && curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt \
    && cd /opt/drake/share/drake/setup && yes | ./install_prereqs \
    && rm -rf /var/lib/apt/lists/* \
    && cd $HOME && rm -rf drake-latest-bionic.tar.gz

RUN mkdir ~/gtest && cd ~/gtest && cmake /usr/src/gtest && make \
    && cp *.a /usr/local/lib \
    && cd $HOME && rm -rf gtest

RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install --upgrade cython
RUN python3 -m pip install --upgrade defusedxml netifaces setuptools wheel virtualenv
# Install pip packages that depend on cython or setuptools already being installed
RUN python3 -m pip install --upgrade msgpack nose2 numpy pyside2 rospkg
# Install pytorch dependencies
RUN python3 -m pip install --upgrade numpy mkl mkl-include cmake cffi typing ecos
RUN python3 -m pip install --upgrade visdom

# RUN cd $HOME \
#     && curl -LO https://download.pytorch.org/libtorch/cu100/libtorch-shared-with-deps-latest.zip \
#     && unzip libtorch-shared-with-deps-latest.zip -d /opt \
#     && cd $HOME && rm libtorch-shared-with-deps-latest.zip
RUN cd $HOME && git clone https://github.com/pytorch/pytorch.git \
    && export _GLIBCXX_USE_CXX11_ABI=1 \
    && export BUILD_CAFFE2_OPS=1 \
    && cd pytorch \
    && git submodule update --init --recursive \
    && python3 setup.py install \
    && cd $HOME && rm -rf pytorch

# install needed ROS packages
RUN apt-get update && apt-get install -q -y \
    dirmngr \
    gnupg2 \
    librosconsole-dev \
    libxmlrpcpp-dev \
    lsb-release \
    libyaml-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

# setup keys
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    python3-rosdep \
    python3-rosinstall \
    python3-vcstools \
    && rm -rf /var/lib/apt/lists/*

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# install ros packages
# =1.4.1-0*
ENV ROS_DISTRO melodic
RUN apt-get update && apt-get install -y \
    ros-melodic-ros-base \
    #ros-melodic-ros-core \
    ros-melodic-geometry2 \
    libpcl-dev \
    ros-melodic-pcl-ros \
    libopencv-dev \
    ros-melodic-vision-opencv \
    && rm -rf /var/lib/apt/lists/*

# setup entrypoint
COPY scripts/docker_entrypoint.sh /root

# install ccd & octomap && fcl
RUN cd $HOME && git clone https://github.com/danfis/libccd.git \
    && cd libccd && mkdir -p build && cd build \
    && cmake -G "Unix Makefiles" .. && make -j 4 && make install \
    && cd $HOME && rm -rf libccd

RUN cd $HOME && git clone https://github.com/OctoMap/octomap.git \
    && cd octomap && mkdir -p build && cd build \
    && cmake -DBUILD_SHARED_LIBS=ON .. && make -j 4 && make install \
    && cd $HOME && rm -rf octomap

RUN cd $HOME && git clone https://github.com/MobileManipulation/fcl.git \
    && cd fcl && mkdir -p build && cd build \
    && cmake -DBUILD_SHARED_LIBS=ON -DFCL_WITH_OCTOMAP=ON -DFCL_HAVE_OCTOMAP=1 .. \
    && make -j 4 && make install \
    && cd $HOME && rm -rf fcl

COPY scripts/install-ompl-ubuntu.sh $HOME
RUN ./install-ompl-ubuntu.sh \
    && cd ompl-1.4.2-Source/build/Release && make install \
    && cd $HOME && rm -rf ompl-1.4.2-Source && rm install-ompl-ubuntu.sh
# RUN apt-get update && apt-get install -y libompl-dev \
#    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade msgpack nose2 numpy pyside2 rospkg

RUN cd $HOME && git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir bin && make \
    && cd $HOME/qpOASES/interfaces/python/ && python3 setup.py install

# # Use a fork, NOT: git clone https://github.com/hungpham2511/toppra $HOME/toppra
RUN cd $HOME && git clone https://github.com/DexaiRobotics/toppra && cd toppra/ \
    && pip3 install -r requirements3.txt \
    && python3 setup.py install \
    && cd $HOME && rm -rf toppra && rm -rf qpOASES

# Install C++ version of msgpack-c (actually for both C and C++)
RUN git clone https://github.com/msgpack/msgpack-c.git \
    && mkdir -p msgpack-c/build && cd msgpack-c/build \
    && cmake -DMSGPACK_CXX11=ON .. && make -j 4 && make install \
    && cd $HOME && rm -rf msgpack-c

RUN git clone https://github.com/rogersce/cnpy.git \
    && mkdir -p cnpy/build && cd cnpy/build \
    && cmake .. && make -j 4 && make install \
    && cd $HOME && rm -rf cnpy

RUN ldconfig

ENTRYPOINT ["docker_entrypoint.sh"]
CMD ["bash"]
