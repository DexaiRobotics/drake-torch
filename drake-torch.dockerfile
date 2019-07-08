ARG BASE_IMAGE=ubuntu:bionic
FROM $BASE_IMAGE
WORKDIR /root

# setup timezone
RUN set -eux && export DEBIAN_FRONTEND=noninteractive \
    && echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && apt-get install -q -y tzdata \
    && rm -rf /var/lib/apt/lists/*

# remove cmake before installing latest cmake-3.14.4
RUN apt-get update -qq && apt-get purge -qy cmake \
    && apt-get install -qy wget git vim nano\
    && rm -rf /var/lib/apt/lists/*

# download, build, install, and remove cmake-3.14.4
RUN wget https://cmake.org/files/v3.14/cmake-3.14.4-Linux-x86_64.tar.gz \
    && tar -xzf cmake-3.14.4-Linux-x86_64.tar.gz \
    && cp -r cmake-3.14.4-Linux-x86_64/bin /usr/ \
    && cp -r cmake-3.14.4-Linux-x86_64/share /usr/ \
    && cp -r cmake-3.14.4-Linux-x86_64/doc /usr/share/ \
    && cp -r cmake-3.14.4-Linux-x86_64/man /usr/share/ \
    && cd $HOME && rm -rf  cmake-3.14.4-Linux-x86_64.tar.gz \
    && rm -rf cmake-3.14.4-Linux-x86_64

# apt install python3 and required modules
RUN apt-get update && apt-get install -q -y python3-dev python3-pip \
    python3-virtualenv \
    libgtest-dev libgflags-dev \
    x11vnc xvfb wget curl unzip xz-utils gzip apt-utils \
    python3-empy python3-nose python3-numpy \
    python3-pip python3-tk python3-yaml \
    && rm -rf /var/lib/apt/lists/*

# install the latest drake (dependencies and the binary)
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && mkdir -p /opt \
    && curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt \
    && cd /opt/drake/share/drake/setup && yes | ./install_prereqs \
    && rm -rf /var/lib/apt/lists/* \
    && cd $HOME && rm -rf drake-latest-bionic.tar.gz

# gtest per recommended method
RUN mkdir ~/gtest && cd ~/gtest && cmake /usr/src/gtest && make \
    && cp *.a /usr/local/lib \
    && cd $HOME && rm -rf gtest

# pip install python packages for toppra, qpOASES, pytorch
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install --upgrade cython defusedxml \
    netifaces setuptools wheel virtualenv msgpack \
    nose2 numpy pyside2 rospkg numpy mkl mkl-include \
    cmake cffi typing ecos visdom

# build pytorch from source
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
    usbutils \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

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

RUN python3 -m pip install --upgrade msgpack nose2 numpy pyside2 rospkg tqdm supervisor

RUN cd $HOME && git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir bin && make\
    && cd $HOME/qpOASES/interfaces/python/ && python3 setup.py install

# # Use Dexai fork, NOT: git clone https://github.com/hungpham2511/toppra $HOME/toppra
RUN cd $HOME && git clone https://github.com/DexaiRobotics/toppra && cd toppra/ \
    && pip3 install -r requirements3.txt \
    && python3 setup.py install \
    && cd $HOME && rm -rf toppra

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
RUN cd $HOME && git clone https://github.com/lcm-proj/lcm.git \
    && cd lcm && mkdir -p build && cd build && cmake .. && make && make install \
    && cd $HOME && rm -rf lcm

# necessary to make all installed libraries available for linking
RUN ldconfig

# setup entrypoint
COPY scripts/docker_entrypoint.sh /root

ENTRYPOINT ["docker_entrypoint.sh"]
CMD ["bash"]
