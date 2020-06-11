ARG BASE_IMAGE
#=ubuntu:bionic
FROM $BASE_IMAGE

USER root
WORKDIR /root

ARG BUILD_TYPE
ARG BUILD_CHANNEL
RUN echo "Oh dang look at that BUILD_TYPE=${BUILD_TYPE}"
RUN echo "Oh dang look at that BASE_IMAGE=${BASE_IMAGE}"
RUN echo "Oh dang look at that BUILD_CHANNEL=${BUILD_CHANNEL}"

########################################################
# initial setup
########################################################

# Set debconf to noninteractive mode.
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# prerequisites for install other apt packages (GPG, keys, cert...)
RUN apt-get update && apt-get install -qy \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    wget \
    && rm -rf /var/lib/apt/lists/*
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null

# apt repo setup in addition to default (cmake etc.)
RUN apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main' \
    && apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic-rc main'

# ensure keyring for cmake stays up to date as kitware rotates their keys
RUN apt-get install kitware-archive-keyring \
    && rm /etc/apt/trusted.gpg.d/kitware.gpg

# setup timezone, install python3 and essential with apt and others with pip
# Install Protobuf Compiler, asked for by Cmake Find for protobuf. Installation suppresses a warning in camke.
# Drake needs protobuf, but not the protobuf compiler, therefore "install_prereqs" does not ask for it.
RUN set -eux \
    && echo 'etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && apt-get install -qy \
    apt-utils \
    openssh-server \
    curl \
    g++ \
    cmake \
    gdb \
    gdbserver \
    rsync \
    git \
    gzip \
    jq \
    vim \
    tzdata \
    unzip \
    x11vnc \
    xvfb \
    xz-utils \
    libgflags-dev \
    libgoogle-glog-dev \
    libgtest-dev \
    libhidapi-dev \
    libiomp-dev \
    libopenmpi-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    protobuf-compiler \
    python3 \
    python3-dev \
    python3-pip \
    # python3-dbg \
    # python3-tk \
    # python3-numpy-dbg \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade --no-cache-dir --compile \
    setuptools wheel pip

# we have to apt-install cmake so the system thinks it is already installed
# then update make to the latest version manually as apt is old
# without the apt install, drake will install old apt version overwriting new one
# # cmake-3.17.3, download, build, install, and remove
# RUN wget -q https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3-Linux-x86_64.tar.gz \
#     && wget -q https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3-SHA-256.txt \
#     && cat cmake-3.17.3-SHA-256.txt | grep cmake-3.17.3-Linux-x86_64.tar.gz | sha256sum --check \
#     && tar -xzf cmake-3.17.3-Linux-x86_64.tar.gz \
#     && cp -r cmake-3.17.3-Linux-x86_64/bin /usr/ \
#     && cp -r cmake-3.17.3-Linux-x86_64/share /usr/ \
#     && cp -r cmake-3.17.3-Linux-x86_64/doc /usr/share/ \
#     && cp -r cmake-3.17.3-Linux-x86_64/man /usr/share/ \
#     && cd $HOME && rm -rf  cmake-3.17.3-Linux-x86_64.tar.gz \
#     && rm -rf cmake-3.17.3-Linux-x86_64
# RUN cmake --version

# gtest per recommended method
RUN set -eux \
    && mkdir ~/gtest && cd ~/gtest && cmake /usr/src/gtest && make \
    && cp *.a /usr/local/lib \
    && cd $HOME && rm -rf gtest

# python packages for toppra, qpOASES, pytorch etc.
RUN python3 -m pip install --upgrade --no-cache-dir --compile \
    typing \
    decorator \
    cython \
    numpy \
    scipy \
    defusedxml \
    empy \
    nose2 \
    netifaces \
    cpppo \
    pyyaml \
    pyserial \
    pyzmq \
    pyside2 \
    msgpack \
    rospkg \
    mkl \
    mkl-include \
    cffi \
    ecos \
    tqdm \
    visdom \
    scikit-image \
    opencv-python \
    munch \
    supervisor \
    sphinx \
    sphinx_rtd_theme \
    breathe \
    jupyterlab \
    import-ipynb

########################################################
# drake
########################################################
# install the latest stable drake release (dependencies and the binary)
# see https://drake.mit.edu/from_binary.html
# and https://github.com/RobotLocomotion/drake/releases
RUN set -eux \
    && mkdir -p /opt \
    %% if [[ $BUILD_CHANNEL == "stable" ]] ; \
    then curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-20200514-bionic.tar.gz | tar -xzC /opt; \
    else curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt; fi \
    && cd /opt/drake/share/drake/setup && yes | ./install_prereqs \
    && rm -rf /var/lib/apt/lists/* \
    && cd $HOME && rm -rf drake*bionic.tar.gz

# pip install pydrake using the /opt/drake directory in develop mode
COPY scripts/setup_pydrake.py /opt/drake/lib/python3.6/site-packages/setup.py
RUN python3 -m pip install -e /opt/drake/lib/python3.6/site-packages

########################################################
# intel MKL
########################################################

RUN wget -q https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
RUN apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && rm GPG-PUB*
RUN sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list'
RUN apt-get update && apt-get -y install intel-mkl-64bit-2019.1-053 \
    && rm -rf /var/lib/apt/lists/*
RUN rm /opt/intel/mkl/lib/intel64/*.so

# Download and build libtorch with MKL support
ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.5"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV BUILD_CAFFE2_OPS=1
ENV _GLIBCXX_USE_CXX11_ABI=1

RUN echo "Using BUILD_TYPE=${BUILD_TYPE}"
RUN set -eux && cd $HOME \
    && if [ $BUILD_TYPE = "cpu" ] ; \
    then wget -q https://download.pytorch.org/libtorch/nightly/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && unzip libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && mv libtorch /usr/local/lib/libtorch \
    && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html -I; \
    else wget -q https://download.pytorch.org/libtorch/nightly/cu101/libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && unzip libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && mv libtorch /usr/local/lib/libtorch \
    && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cu101/torch_nightly.html -I; fi \
    && rm $HOME/libtorch*.zip

########################################################
# ROS
########################################################

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list

# install needed ROS packages
RUN apt-get update && apt-get install -qy \
    dirmngr \
    librosconsole-dev \
    libxmlrpcpp-dev \
    lsb-release \
    libyaml-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -qy \
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
ENV ROS_DISTRO melodic
RUN apt-get update && apt-get install -y \
    ros-melodic-ros-base \
    ros-melodic-geometry2 \
    libpcl-dev \
    ros-melodic-pcl-ros \
    libopencv-dev \
    ros-melodic-vision-opencv \
    ros-melodic-xacro \
    ros-melodic-rospy-message-converter \
    ros-melodic-image-transport \
    ros-melodic-rgbd-launch \
    ros-melodic-ddynamic-reconfigure \
    ros-melodic-diagnostic-updater \
    ros-melodic-robot-state-publisher \
    ros-melodic-joint-state-publisher \
    python-catkin-tools \
    usbutils \
    software-properties-common \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# install cv_bridge to /opt/ros/melodic from source
SHELL ["/bin/bash", "-c"]
RUN cd $HOME && mkdir -p py3_ws/src && cd py3_ws/src \
    && git clone -b melodic https://github.com/ros-perception/vision_opencv.git \
    && git clone -b melodic-devel https://github.com/ros/ros_comm.git \
    && cd $HOME/py3_ws \
    && python3 -m pip install --upgrade --no-cache-dir --compile \
    catkin_tools \
    pycryptodomex \
    gnupg \
    && source /opt/ros/melodic/setup.bash \
    && export ROS_PYTHON_VERSION=3 \
    && catkin config --install \
        --install-space /opt/ros/melodic \
        --cmake-args \
            -DPYTHON_EXECUTABLE=/usr/bin/python3 \
            -DPYTHON_INCLUDE_DIR=/usr/include/python3.6m \
            -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.6m.so \
    && catkin build && rm -rf $HOME/py3_ws

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

# note - install-ompl-ubuntu is copied from https://ompl.kavrakilab.org/install-ompl-ubuntu.sh
# this script was modifed to remove sudo to work in the docker; otherwise identical
COPY scripts/install-ompl-ubuntu.sh $HOME
RUN ./install-ompl-ubuntu.sh \
    && cd ompl-1.4.2-Source/build/Release && make install \
    && cd $HOME && rm -rf ompl-1.4.2-Source && rm install-ompl-ubuntu.sh

# Install python URDF parser
RUN cd $HOME && git clone https://github.com/ros/urdf_parser_py && cd urdf_parser_py \
    && python3 setup.py install \
    && cd $HOME && rm -rf urdf_parser_py

########################################################
# bash fix: for broken interactive shell detection
########################################################
COPY scripts/fix_bashrc.sh $HOME
RUN ./fix_bashrc.sh && rm ./fix_bashrc.sh

########################################################
# other dexai stack dependencies
########################################################

# qpOASES
RUN cd $HOME && git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir -p bin && make\
    && cd $HOME/qpOASES/interfaces/python/ && python3 setup.py install \
    && rm -rf $HOME/qpOASES

# toppra: Dexai fork
RUN cd $HOME && git clone https://github.com/DexaiRobotics/toppra && cd toppra/ \
    && python3 -m pip install --upgrade --no-cache-dir --compile -r requirements3.txt \
    && python3 setup.py install \
    && rm -rf $HOME/toppra

# Install C++ branch of msgpack-c
RUN cd $HOME && git clone -b cpp_master https://github.com/msgpack/msgpack-c.git \
    && cd msgpack-c && cmake -DMSGPACK_CXX17=ON . && make install \
    && cd $HOME && rm -rf msgpack-c

# cnpy lets you read and write numpy formats in C++, needed by libstuffgetter.so
RUN git clone https://github.com/rogersce/cnpy.git \
    && mkdir -p cnpy/build && cd cnpy/build \
    && cmake .. && make -j 4 && make install \
    && cd $HOME && rm -rf cnpy

# librealsense and the realsense SDK
RUN apt-key adv --keyserver keys.gnupg.net --recv-key C8B3A55A6F3EFCDE \
    || apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key C8B3A55A6F3EFCDE \
    && add-apt-repository "deb http://realsense-hw-public.s3.amazonaws.com/Debian/apt-repo bionic main" -u \
    && apt-get update && apt-get install -y \
    librealsense2-dkms \
    librealsense2-utils \
    librealsense2-dev \
    librealsense2-dbg \
    librealsense2 \
    && rm -rf /var/lib/apt/lists/*

# install LCM system-wide
RUN cd $HOME && git clone https://github.com/lcm-proj/lcm \
    && cd lcm && mkdir -p build && cd build && cmake .. && make && make install \
    && cd $HOME && rm -rf lcm

# install libfranka system-wide
RUN cd $HOME && git clone https://github.com/frankaemika/libfranka.git \
    && cd libfranka && git checkout 0.5.0 && git submodule update --init \
    && mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make && make install \
    && cd $HOME && rm -rf libfranka

########################################################
# Essential packages for remote debugging and login in
########################################################

# install nice-to-have some dev tools
RUN apt-get update && apt-get install -qy \
    htop \
    nano \
    tig \
    tmux \
    tree \
    git-extras \
    clang-format-8 \
    espeak-ng-espeak \
    iwyu \
    ros-melodic-tf-conversions \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install git-lfs -y \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    doxygen \
    && rm -rf /var/lib/apt/lists/*

# RUN cd $HOME && git clone https://github.com/google/protobuf.git \
#     && cd protobuf && git submodule update --init --recursive \
#     && ./autogen.sh \
#     && ./configure \
#     && make && make check && make install && ldconfig \
#     && cd $HOME && rm -rf protobuf

# Taken from - https://docs.docker.com/engine/examples/running_ssh_service/#environment-variables
RUN mkdir /var/run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Change Docker Port from 22 to 7776 for ssh server.
# This is needed so that docker can run in net=host mode and both the host and the docker run an ssh server
RUN sed -i 's/#Port 22/Port 7776/' /etc/ssh/sshd_config

# Port 7776 for ssh server. 7777 for gdb server.
EXPOSE 7776 7777

# RUN useradd -ms /bin/bash debugger
# RUN echo 'debugger:pwd' | chpasswd

########################################################
# final steps
########################################################

# necessary to make all installed libraries available for linking
RUN ldconfig

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

# start ssh daemon
CMD ["/usr/sbin/sshd", "-D"]
