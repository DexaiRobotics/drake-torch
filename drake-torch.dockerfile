ARG BASE_IMAGE
#=ubuntu:bionic
FROM $BASE_IMAGE
USER root
WORKDIR /root

ARG BUILD_TYPE
ARG BUILD_CHANNEL
RUN echo "Oh dang look at that BUILD_TYPE=${BUILD_TYPE}"
RUN echo "Oh dang look at that BUILD_CHANNEL=${BUILD_CHANNEL}"

########################################################
# initial setup
########################################################

# Set debconf to noninteractive mode.
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# prerequisites for install other apt packages (GPG, keys, cert...)
# we have to apt-install cmake so the system thinks it is already installed
# then update make to the latest version manually as apt is old
# without the apt install, drake will install old apt version overwriting new one

RUN apt-get update \
    && apt-get install -qy \
        gnupg2 \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        wget
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null

# apt repo setup in addition to default (cmake etc.)
RUN add-apt-repository 'deb https://apt.kitware.com/ubuntu/ bionic main' \
    && add-apt-repository ppa:ubuntu-toolchain-r/test -y \
    && add-apt-repository ppa:git-core/ppa -y

# ensure keyring for cmake stays up to date as kitware rotates their keys
RUN apt-get install -qy kitware-archive-keyring \
    && rm /etc/apt/trusted.gpg.d/kitware.gpg

# setup timezone, install python3 and essential with apt and others with pip
# Install Protobuf Compiler, asked for by Cmake Find for protobuf. Installation suppresses a warning in cmake.
RUN set -eux \
    && echo 'etc/UTC' > /etc/timezone \
    && ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime \
    && apt-get update && apt-get install -qy \
        apt-utils \
        openssh-server \
        curl \
        gcc-9 \
        g++-9 \
        gcc-10 \
        g++-10 \
        cmake \
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
        libhidapi-dev \
        libiomp-dev \
        libopenmpi-dev \
        libudev-dev \
        libusb-1.0-0-dev \
        protobuf-compiler \
        python3 \
        python3-dev \
        python3-pip

RUN update-alternatives \
        --install /usr/bin/gcc gcc /usr/bin/gcc-10 90 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-10 \
        --slave /usr/bin/gcov gcov /usr/bin/gcov-10

RUN python3 -m pip install --upgrade --no-cache-dir --compile \
        setuptools wheel pip

# gtest per recommended method, needed by msgpack etc.
RUN cd $HOME \
    && \
        if [ $BUILD_CHANNEL = "stable" ] ; \
        then \
            curl -SL https://github.com/google/googletest/archive/release-1.8.1.tar.gz | tar -xz \
            && cd googletest-release-1.8.1 \
            && mkdir build \
            && cd build \
            && cmake .. \
            && make -j 12 \
            && cp -r ../googletest/include /usr/local/include \
            && cp googlemock/gtest/*.a /usr/local/lib \
            && cd $HOME && rm -rf googletest-release-1.8.1 release-1.8.1.tar.gz; \
        else \
            curl -SL https://github.com/google/googletest/archive/release-1.10.0.tar.gz | tar -xz \
            && cd googletest-release-1.10.0 \
            && mkdir build \
            && cd build \
            && cmake .. \
            && make -j 12 \
            && cp -r ../googletest/include /usr/local/include \
            && cp lib/*.a /usr/local/lib \
            && cd $HOME && rm -rf googletest-release-1.10.0 release-1.10.0.tar.gz; \
        fi

# install make 4.3 and GDB 9.2
RUN cd $HOME \
    && curl -SL https://ftp.gnu.org/gnu/make/make-4.3.tar.gz | tar -xz \
    && cd make-4.3 \
    && mkdir build \
    && cd build \
    && ../configure --prefix=/usr \
    && make -j 12 \
    && make install \
    && cd $HOME \
    && rm -rf make-4.3
# texinfo is needed for building gdb 9.2 even in the presence of make 4.3
RUN apt-get install texinfo -qy
RUN cd $HOME \
    && curl -SL https://ftp.gnu.org/gnu/gdb/gdb-9.2.tar.xz | tar -xJ \
    && cd gdb-9.2 \
    && mkdir build \
    && cd build \
    && ../configure \
        --prefix=/usr \
        # --with-system-readline \
        --with-python=/usr/bin/python3 \
    && make -j 12 \
    && make install \
    && cd $HOME \
    && rm -rf gdb-9.2

# python packages for toppra, qpOASES, etc.
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
        visdom \
        munch \
        supervisor \
        sphinx \
        sphinx_rtd_theme

# OpenCV 4.4.0 release library (for C++ and Python)
RUN apt-get install -qy \
        python-numpy \
        libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev \
        libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev \
    && cd $HOME \
    && curl -SL https://github.com/opencv/opencv/archive/4.4.0.tar.gz | tar -xz \
    && cd opencv-4.4.0 \
    && mkdir build \
    && cd build \
    && cmake \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D PYTHON3_EXECUTABLE=/usr/bin/python3 \
        -D PYTHON_INCLUDE_DIR=/usr/include/python3.6m \
        -D PYTHON_INCLUDE_DIR2=/usr/include/x86_64-linux-gnu/python3.6m \
        -D PYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.6m.so \
        -D PYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include \
        .. \
    && make -j 12 \
    && make install \
    && cd $HOME \
    && rm -rf 4.4.0.tar.gz

##############################################################
# libtorch and pytorch, torchvision with intel MKL support
##############################################################

RUN wget -q https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
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
    && \
        if [ $BUILD_TYPE = "cpu" ]; then \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                wget -q https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-1.6.0%2Bcpu.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile torch==1.6.0+cpu torchvision==0.7.0+cpu -f https://download.pytorch.org/whl/torch_stable.html; \
            else \
                wget -q https://download.pytorch.org/libtorch/nightly/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html; \
            fi; \
        else \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                wget -q https://download.pytorch.org/libtorch/cu102/libtorch-cxx11-abi-shared-with-deps-1.6.0.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile torch torchvision; \
            else \
                wget -q https://download.pytorch.org/libtorch/nightly/cu102/libtorch-cxx11-abi-shared-with-deps-latest.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cu102/torch_nightly.html; \
            fi; \
        fi \
    && unzip libtorch-cxx11-abi-shared-with-deps-*.zip \
    && mv libtorch /usr/local/lib/libtorch \
    && rm $HOME/libtorch*.zip

########################################################
# drake
########################################################
# install the latest stable drake release (dependencies and the binary)
# see https://drake.mit.edu/from_binary.html
# and https://github.com/RobotLocomotion/drake/releases
RUN set -eux \
    && mkdir -p /opt \
    && \
        if [ $BUILD_CHANNEL = "stable" ] ; \
        then curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-20200514-bionic.tar.gz | tar -xzC /opt; \
        else curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt; \
        fi \
    && cd /opt/drake/share/drake/setup && yes | ./install_prereqs \
    && cd $HOME && rm -rf drake*bionic.tar.gz

# pip install pydrake using the /opt/drake directory in develop mode
COPY scripts/setup_pydrake.py /opt/drake/lib/python3.6/site-packages/setup.py
RUN python3 -m pip install -e /opt/drake/lib/python3.6/site-packages

# drake's install_prereqs script installed old version of terminado
# incompatible with pip jupyter suite so get rid of it
# install jupyter suite properly and update components
RUN apt-get remove python3-terminado -qy \
    && python3 -m pip install --upgrade --no-cache-dir --compile \
        ipython ipykernel jupyterlab nbconvert

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
    libyaml-cpp-dev

# install bootstrap tools
RUN apt-get install --no-install-recommends -qy \
        python3-rosdep \
        python3-rosinstall \
        python3-vcstools

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# install ros packages
ENV ROS_DISTRO melodic
RUN apt-get install -qy \
        ros-melodic-ros-base \
        ros-melodic-geometry2 \
        libpcl-dev \
        ros-melodic-pcl-ros \
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
        iputils-ping

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
            -DOPENCV_VERSION_MAJOR=4 \
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

COPY scripts/install-ompl-ubuntu.sh $HOME
RUN cd $HOME \
    && ./install-ompl-ubuntu.sh --python \
    && rm -rf install-ompl-ubuntu.sh castxml fcl-0.6.1 ompl-1.4.2

# Install python URDF parser
RUN cd $HOME && git clone https://github.com/ros/urdf_parser_py && cd urdf_parser_py \
    && python3 setup.py install \
    && cd $HOME && rm -rf urdf_parser_py

# reinstall opencv 4 to fix symlinks
RUN cd $HOME/opencv-4.4.0/build \
    && make install \
    && cd $HOME \
    && rm -rf opencv-4.4.0

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
    && cd $HOME/qpOASES/ && mkdir -p bin && make -j 12 \
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
    && cmake .. && make -j 12 && make install \
    && cd $HOME && rm -rf cnpy

# realsense SDK, apt install instructions take from
# https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md
# manual install instructions availabe at
# https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md
RUN apt-key adv --keyserver keys.gnupg.net --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE  \
    || apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE  \
    && add-apt-repository "deb http://realsense-hw-public.s3.amazonaws.com/Debian/apt-repo bionic main" -u \
    && apt-get update && apt-get install -qy \
        librealsense2-dkms \
        librealsense2-utils \
        librealsense2-dev \
        librealsense2-dbg \
        librealsense2

# install LCM system-wide
RUN cd $HOME && git clone https://github.com/lcm-proj/lcm \
    && cd lcm && mkdir -p build && cd build && cmake .. \
    && make -j 12 \
    && make install \
    && cd $HOME && rm -rf lcm

########################################################
# Essential packages for remote debugging and login in
########################################################

# install nice-to-have some dev tools
# only clear apt lists at the last apt call
# gazebo and rviz needed for sim robot
RUN apt-get upgrade -qy \
    && apt-get install -qy \
        htop \
        nano \
        tig \
        tmux \
        tree \
        git-extras \
        clang-format-8 \
        espeak-ng-espeak \
        iwyu \
        screen \
        ros-melodic-tf-conversions \
        ros-melodic-gazebo-ros \
        ros-melodic-rviz \
        git-lfs \
        doxygen \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/*

RUN git lfs install

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
