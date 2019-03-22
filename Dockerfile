FROM ubuntu:bionic

WORKDIR /root
# COPY src/drake/setup/ubuntu setup/ubuntu
COPY scripts scripts

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
RUN wget https://cmake.org/files/v3.13/cmake-3.13.4-Linux-x86_64.tar.gz
RUN tar -xzf cmake-3.13.4-Linux-x86_64.tar.gz
RUN cp -r cmake-3.13.4-Linux-x86_64/bin /usr/
RUN cp -r cmake-3.13.4-Linux-x86_64/share /usr/
RUN cp -r cmake-3.13.4-Linux-x86_64/doc /usr/share/
RUN cp -r cmake-3.13.4-Linux-x86_64/man /usr/share/

RUN set -eux \
  && export DEBIAN_FRONTEND=noninteractive \
  && cd $HOME && git clone https://github.com/RobotLocomotion/drake.git \
  && yes | drake/setup/ubuntu/install_prereqs.sh \
  && rm -rf /var/lib/apt/lists/* \
  && cd $HOME && rm -rf drake/

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
cd /opt && git clone https://github.com/DexaiRobotics/pytorch.git \
    && cd pytorch && git submodule update --init --recursive \
    && cd tools && python3 build_libtorch.pyRUN python3 -m pip install --upgrade numpy mkl mkl-include cmake cffi typing 
# pyyaml
RUN python3 -m pip install --upgrade visdom

RUN cd /opt && git clone https://github.com/DexaiRobotics/pytorch.git \
    && cd pytorch && git submodule update --init --recursive \
    && cd tools && python3 build_libtorch.py

# ENTRYPOINT ["scripts/cartpole_entrypoint.sh"]

# install needed ROS packages
RUN apt-get update && apt-get install -q -y \
    dirmngr \
    gnupg2 \
    librosconsole-dev \
    libxmlrpcpp-dev \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# setup keys
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 421C365BD9FF1F717815A3895523BAEEB01FA116

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    python-rosdep \
    python-rosinstall \
    python-vcstools \
    && rm -rf /var/lib/apt/lists/*

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# install ros packages
ENV ROS_DISTRO melodic
RUN apt-get update && apt-get install -y \
    ros-melodic-ros-core=1.4.1-0* \
    ros-melodic-geometry2 \
    libpcl-dev \
    ros-melodic-pcl-ros \
    && rm -rf /var/lib/apt/lists/*

# setup entrypoint
COPY scripts/ros_entrypoint.sh /root

# install gtest
RUN apt-get update && apt-get install libgtest-dev \
    && cd /usr/src/gtest && mkdir -p build && cd build \
    && echo "Copying libgtest* files directly to /usr/lib/ (in lieu of `make install`)" \
    && cmake -DBUILD_SHARED_LIBS=ON .. && make -j 4 && cp libgtest* /usr/lib/ \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install libeigen3-dev \
    && rm -rf /var/lib/apt/lists/*

# install ccd & octomap && fcl
RUN cd $HOME && git clone https://github.com/danfis/libccd.git \
    && cd libccd && mkdir -p build && cd build \
    && cmake -G "Unix Makefiles" .. && make -j 4 && make install

RUN cd $HOME && git clone https://github.com/OctoMap/octomap.git \
    && cd octomap && mkdir -p build && cd build \
    && cmake -DBUILD_SHARED_LIBS=ON .. && make -j 4 && make install

# ENV EIGEN_INCLUDE_DIR "/opt/drake/include/eigen3"
# ENV EIGEN3_INCLUDE_DIR "/opt/drake/include/eigen3"

RUN cd $HOME && git clone https://github.com/MobileManipulation/fcl.git \
    && cd fcl && mkdir -p build && cd build \
    && cmake -DBUILD_SHARED_LIBS=ON -DFCL_WITH_OCTOMAP=ON -DFCL_HAVE_OCTOMAP=1 .. \
    && make -j 4 && make install

COPY scripts/install_ompl_ubuntu_1.3.2.sh /root
RUN cd /root && chmod u+x install_ompl_ubuntu_1.3.2.sh && ./install_ompl_ubuntu_1.3.2.sh

RUN python3 -m pip install --upgrade msgpack nose2 numpy pyside2 rospkg
RUN cd $HOME && git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir bin && make \
    && cd $HOME/qpOASES/interfaces/python/ && python setup.py install
# Use a fork, NOT: git clone https://github.com/hungpham2511/toppra $HOME/toppra
RUN cd /opt && git clone https://github.com/MobileManipulation/toppra.git \
    && cd toppra && pip install --upgrade -r requirements.txt && python setup.py install
# Install C++ version of msgpack-c (actually for both C and C++)
RUN git clone https://github.com/msgpack/msgpack-c.git \
    && mkdir -p msgpack-c/build && cd msgpack-c/build \
    && cmake -DMSGPACK_CXX11=ON .. && make -j 4 && make install

RUN ldconfig

ENTRYPOINT ["ros_entrypoint.sh"] 
CMD ["bash"]
