ARG BASE_IMAGE
#=ubuntu:bionic
FROM $BASE_IMAGE

USER root
WORKDIR /root

ARG BUILD_TYPE
RUN echo "Oh dang look at that BUILD_TYPE=${BUILD_TYPE}"
RUN echo "Oh dang look at that BASE_IMAGE=${BASE_IMAGE}"

# Set debconf to noninteractive mode.
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y gnupg2

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32

# setup timezone, install python3 and required modules
# Install Protobuf Compiler, asked for by Cmake Find for protobuf. Installation suppresses a warning in camke.
# Drake needs protobuf, but not the protobuf compiler, therefore "install_prereqs" does not ask for it.
RUN set -eux \
    && echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get -y update && apt-get -y upgrade && apt-get install -q -y \
    apt-utils \
    curl \
    g++ \
    git \
    gzip \
    jq \
    libgflags-dev \
    libgoogle-glog-dev \
    libgtest-dev \
    libhidapi-dev \
    libiomp-dev \
    libopenmpi-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    nano \
    protobuf-compiler \
    python3 \
    python3-dev \
    python3-empy \
    python3-nose \
    python3-numpy \
    python3-pip \
    python3-setuptools \
    python3-tk \
    python3-virtualenv \
    python3-yaml \
    tzdata \
    unzip \
    vim \
    wget \
    x11vnc \
    xvfb \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# download, build, install, and remove cmake-3.17.1
RUN wget https://github.com/Kitware/CMake/releases/download/v3.17.1/cmake-3.17.1-Linux-x86_64.tar.gz \
    && wget https://github.com/Kitware/CMake/releases/download/v3.17.1/cmake-3.17.1-SHA-256.txt \
    && cat cmake-3.17.1-SHA-256.txt | grep cmake-3.17.1-Linux-x86_64.tar.gz | sha256sum --check \
    && tar -xzf cmake-3.17.1-Linux-x86_64.tar.gz \
    && cp -r cmake-3.17.1-Linux-x86_64/bin /usr/ \
    && cp -r cmake-3.17.1-Linux-x86_64/share /usr/ \
    && cp -r cmake-3.17.1-Linux-x86_64/doc /usr/share/ \
    && cp -r cmake-3.17.1-Linux-x86_64/man /usr/share/ \
    && cd $HOME && rm -rf  cmake-3.17.1-Linux-x86_64.tar.gz \
    && rm -rf cmake-3.17.1-Linux-x86_64

# install the latest stable drake release (dependencies and the binary)
# see https://drake.mit.edu/from_binary.html
# and https://github.com/RobotLocomotion/drake/releases
RUN set -eux \
    && mkdir -p /opt \
    && curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-20200514-bionic.tar.gz | tar -xzC /opt \
    # && curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt \
    && cd /opt/drake/share/drake/setup && yes | ./install_prereqs \
    && rm -rf /var/lib/apt/lists/* \
    && cd $HOME && rm -rf drake*bionic.tar.gz

# gtest per recommended method
RUN set -eux \
    && mkdir ~/gtest && cd ~/gtest && cmake /usr/src/gtest && make \
    && cp *.a /usr/local/lib \
    && cd $HOME && rm -rf gtest

# pip install python packages for toppra, qpOASES, pytorch
RUN python3 -m pip install --upgrade setuptools wheel pip
RUN python3 -m pip install --upgrade cython defusedxml \
    netifaces msgpack \
    nose2 pyside2 rospkg numpy mkl mkl-include \
    cffi typing ecos visdom opencv-python munch

# Intel MKL installation

RUN wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
RUN apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && rm GPG-PUB*
RUN sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list'
RUN apt-get update && apt-get -y install intel-mkl-64bit-2019.1-053
RUN rm /opt/intel/mkl/lib/intel64/*.so

# Download and build libtorch with MKL support
ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.5"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV BUILD_CAFFE2_OPS=1
ENV _GLIBCXX_USE_CXX11_ABI=1

RUN echo "Using BUILD_TYPE=${BUILD_TYPE}"
RUN set -eux && cd $HOME \
    && if [ $BUILD_TYPE = "cpu" ] ; \
    then wget https://download.pytorch.org/libtorch/nightly/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && unzip libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && mv libtorch /usr/local/lib/libtorch \
    && python3 -m pip install --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html -I; \
    else wget https://download.pytorch.org/libtorch/nightly/cu101/libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && unzip libtorch-cxx11-abi-shared-with-deps-latest.zip \
    && mv libtorch /usr/local/lib/libtorch \
    && python3 -m pip install --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cu101/torch_nightly.html -I; fi \
    && python3 -m pip install ipython -I \
    && python3 -m pip install jupyter -I

# setup keys
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list

# install needed ROS packages
RUN apt-get update && apt-get install -q -y \
    dirmngr \
    gnupg2 \
    librosconsole-dev \
    libxmlrpcpp-dev \
    lsb-release \
    libyaml-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

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
    && python3 -m pip install catkin_tools pycryptodomex gnupg \
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

# fix broken interactive shell detection in bashrc
COPY scripts/fix_bashrc.sh $HOME
RUN ./fix_bashrc.sh && rm ./fix_bashrc.sh

# pip install pydrake using the /opt/drake directory in develop mode
COPY scripts/setup_pydrake.py /opt/drake/lib/python3.6/site-packages/setup.py
RUN python3 -m pip install -e /opt/drake/lib/python3.6/site-packages

RUN python3 -m pip install --upgrade cpppo msgpack nose2 numpy pyside2 rospkg tqdm supervisor

RUN cd $HOME && git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir -p bin && make\
    && cd $HOME/qpOASES/interfaces/python/ && python3 setup.py install

# # Use Dexai fork, NOT: git clone https://github.com/hungpham2511/toppra $HOME/toppra
RUN cd $HOME && git clone https://github.com/DexaiRobotics/toppra && cd toppra/ \
    && python3 -m pip install -r requirements3.txt \
    && python3 setup.py install \
    && cd $HOME

# Install python URDF parser
RUN cd $HOME && git clone https://github.com/ros/urdf_parser_py && cd urdf_parser_py \
    && python3 setup.py install \
    && cd $HOME && rm -rf urdf_parser_py

# Install C++ version of msgpack-c (actually for both C and C++)
RUN git clone https://github.com/msgpack/msgpack-c.git \
    && mkdir -p msgpack-c/build && cd msgpack-c/build \
    && cmake -DMSGPACK_CXX11=ON .. && make -j 4 && make install \
    && cd $HOME && rm -rf msgpack-c

# cnpy enables serialization of numpy files .npy and .npz
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

RUN apt-get update && apt-get install -y \
    openssh-server gdb gdbserver rsync python3-dbg python3-numpy-dbg \
    && rm -rf /var/lib/apt/lists/*

# download, build, install, and remove cmake-3.17.1
RUN wget https://github.com/Kitware/CMake/releases/download/v3.17.1/cmake-3.17.1-Linux-x86_64.tar.gz \
    && wget https://github.com/Kitware/CMake/releases/download/v3.17.1/cmake-3.17.1-SHA-256.txt \
    && cat cmake-3.17.1-SHA-256.txt | grep cmake-3.17.1-Linux-x86_64.tar.gz | sha256sum --check \
    && tar -xzf cmake-3.17.1-Linux-x86_64.tar.gz \
    && cp -r cmake-3.17.1-Linux-x86_64/bin /usr/ \
    && cp -r cmake-3.17.1-Linux-x86_64/share /usr/ \
    && cp -r cmake-3.17.1-Linux-x86_64/doc /usr/share/ \
    && cp -r cmake-3.17.1-Linux-x86_64/man /usr/share/ \
    && cd $HOME && rm -rf  cmake-3.17.1-Linux-x86_64.tar.gz \
    && rm -rf cmake-3.17.1-Linux-x86_64

# install nice-to-have some dev tools
RUN apt install -q -y \
    clang-format-8 \
    espeak-ng-espeak \
    iwyu \
    ros-melodic-tf-conversions \
    tig \
    tmux \
    tree \
    htop \
    git-extras

RUN apt install git-lfs -y \
    && git lfs install

RUN apt install --reinstall -q -y \
    python*-decorator \
    doxygen \
    python3-sphinx

RUN cd $HOME && git clone https://github.com/google/protobuf.git \
    && cd protobuf && git submodule update --init --recursive \
    && ./autogen.sh \
    && ./configure \
    && make && make check && make install && ldconfig \
    && cd $HOME && rm -rf protobuf

# post install cleanup
RUN rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install -U \
    pyyaml pyserial pyzmq scipy \
    scikit-image sphinx sphinx_rtd_theme breathe import-ipynb jupyter

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
# END of Essential packages for remote debugging and login in
########################################################

# necessary to make all installed libraries available for linking
RUN ldconfig

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

# start ssh daemon
CMD ["/usr/sbin/sshd", "-D"]
