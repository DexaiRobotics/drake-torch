ARG BASE_IMAGE
FROM $BASE_IMAGE
USER root
WORKDIR /root
ARG BUILD_TYPE

# Set debconf to noninteractive mode
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -qy

# OpenCV 4.4.0 for C++ and Python3 before ROS
RUN apt-get install -qy \
        python3-numpy \
        libgtk-3-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev \
        libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev
RUN curl -SL https://github.com/opencv/opencv/archive/4.4.0.tar.gz | tar -xz \
    && cd opencv-4.4.0 \
    && mkdir build \
    && cd build \
    && cmake .. \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D PYTHON3_EXECUTABLE=/usr/bin/python3 \
        -D PYTHON_INCLUDE_DIR=/usr/include/python3.6 \
        -D PYTHON_INCLUDE_DIR2=/usr/include/x86_64-linux-gnu/python3.6 \
        -D PYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.6.so \
        -D PYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include \
    && make install -j 12 \
    && rm -rf $HOME/4.4.0.tar.gz

# ########################################################
# ROS
# http://wiki.ros.org/noetic/Installation/Ubuntu
# ########################################################

# set locale
ENV LANG='C.UTF-8' LC_ALL='C.UTF-8'
# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list
# setup keys
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# uninstall latest libboost before ROS attemps to install the old version
RUN apt-get purge -qy libboost1.74-dev

RUN apt-get update && apt-get install -qy \
    ros-melodic-ros-base \
    ros-melodic-geometry2 \
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
    ros-melodic-tf-conversions \
    ros-melodic-gazebo-ros \
    ros-melodic-rviz \
    dirmngr \
    libpcl-dev \
    librosconsole-dev \
    libxmlrpcpp-dev \
    lsb-release \
    libyaml-cpp-dev

RUN apt-get install --no-install-recommends -qy \
        python3-rosdep \
        python3-rosinstall
        # python-rosinstall-generator
        # python3-vcstools
        # python-wstool
# bootstrap rosdep
RUN rosdep init && rosdep update

# install boost 1.74 without removing libboost 1.71 on which ROS depends
RUN curl -SL https://dl.bintray.com/boostorg/release/1.74.0/source/boost_1_74_0.tar.bz2 | tar -xj \
    && cd boost_1_74_0 \
    && ./bootstrap.sh --prefix=/usr --with-python=python3 \
    && ./b2 stage -j 12 threading=multi link=shared \
    && ./b2 install threading=multi link=shared

# reinstall googletest to overwrite old version that's part of rosdep
RUN cd /usr/src \
    && rm -rf gtest gmock googletest \
    && cd /usr/include \
    && rm -rf gtest gmock \
    && cd /usr/local/lib \
    && rm -rf libgtest* libgtest*
RUN cd $HOME/googletest-release-1.10.0/build \
    && make install \
    && cd $HOME \
    && rm -rf googletest-release-1.10.0 release-1.10.0.tar.gz

# reinstall opencv 4 to fix symlinks
RUN cd $HOME/opencv-4.4.0/build \
    && make install \
    && rm -rf $HOME/opencv-4.4.0

########################################################
# dev essentials and other dependencies
########################################################

RUN apt-get install -qy \
        libgflags-dev \
        git \
        git-extras \
        git-lfs \
        tig \
        htop \
        screen \
        xvfb \
        x11vnc \
        tmux \
        tree \
        clang-format-10 \
        iwyu \
        doxygen

RUN git lfs install

# Install C++ branch of msgpack-c
RUN cd $HOME && git clone -b cpp_master https://github.com/msgpack/msgpack-c.git \
    && cd msgpack-c && cmake -DMSGPACK_CXX17=ON . && make install -j 12 \
    && cd $HOME && rm -rf msgpack-c

# install ccd & octomap && fcl
RUN cd $HOME && git clone https://github.com/danfis/libccd.git \
    && cd libccd && mkdir -p build && cd build \
    && cmake -G "Unix Makefiles" .. && make install -j 12 \
    && rm -rf $HOME/libccd

RUN cd $HOME && git clone https://github.com/OctoMap/octomap.git \
    && cd octomap && mkdir -p build && cd build \
    && cmake -D OpenGL_GL_PREFERENCE=LEGACY -D BUILD_SHARED_LIBS=ON .. \
    && make install -j 12 \
    && rm -rf $HOME/octomap

RUN cd $HOME && git clone https://github.com/MobileManipulation/fcl.git \
    && cd fcl && mkdir -p build && cd build \
    && cmake -DBUILD_SHARED_LIBS=ON -DFCL_WITH_OCTOMAP=ON -DFCL_HAVE_OCTOMAP=1 .. \
    && make install -j 12 \
    && rm -rf $HOME/fcl

# RUN python3 -m pip install --upgrade --no-cache-dir --compile pyplusplus
# RUN apt-get update && apt-get install -qy python-pip
# COPY in_container_scripts/install-ompl-ubuntu.sh install-ompl-ubuntu.sh
RUN wget https://ompl.kavrakilab.org/install-ompl-ubuntu.sh \
    && chmod +x install-ompl-ubuntu.sh \
    && ./install-ompl-ubuntu.sh --python \
    && rm -rf /usr/local/include/ompl \
    && ln -s /usr/local/include/ompl-1.5/ompl /usr/local/include/ompl \
    && rm $HOME/install-ompl-ubuntu.sh

# Install python URDF parser
RUN git clone https://github.com/ros/urdf_parser_py && cd urdf_parser_py \
    && python3 setup.py install \
    && cd $HOME && rm -rf urdf_parser_py

# qpOASES
RUN git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir -p bin && make -j 12 \
    && cd $HOME/qpOASES/interfaces/python/ && python3 setup.py install \
    && rm -rf $HOME/qpOASES

# toppra: Dexai fork
RUN git clone https://github.com/DexaiRobotics/toppra \
    && python3 -m pip install --upgrade --no-cache-dir --compile ./toppra \
    && rm -rf toppra

# cnpy lets you read and write numpy formats in C++, needed by libstuffgetter.so
RUN git clone https://github.com/rogersce/cnpy.git \
    && mkdir -p cnpy/build && cd cnpy/build \
    && cmake .. && make -j 12 && make install \
    && cd $HOME && rm -rf cnpy

# install LCM system-wide
RUN git clone https://github.com/lcm-proj/lcm \
    && cd lcm && mkdir -p build && cd build && cmake .. \
    && make -j 12 \
    && make install \
    && cd $HOME && rm -rf lcm

# build librealsense from source since there's no 20.04 support
RUN apt-get install -qy \
        libssl-dev \
        libusb-1.0-0-dev \
        pkg-config \
        libgtk-3-dev \
        libglfw3-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
    && git clone https://github.com/IntelRealSense/librealsense.git \
    && cd librealsense \
    && scripts/setup_udev_rules.sh
RUN cd librealsense \
    && mkdir build \
    && cd build \
    && \
        if [ $BUILD_TYPE = "cpu" ]; then \
            cmake .. \
                -D CMAKE_BUILD_TYPE=Release \
                -D BUILD_PYTHON_BINDINGS:bool=true \
                -D PYTHON_EXECUTABLE=/usr/bin/python3; \
        else \
            cmake .. \
                -D CMAKE_BUILD_TYPE=Release \
                -D BUILD_PYTHON_BINDINGS:bool=true \
                -D PYTHON_EXECUTABLE=/usr/bin/python3 \
                -D BUILD_WITH_CUDA:bool=true \
                -D CMAKE_CUDA_ARCHITECTURES="75" \
                -D CMAKE_CUDA_HOST_COMPILER=gcc-9 \
                -D OpenGL_GL_PREFERENCE=GLVND; \
        fi \
    && make uninstall \
    && make clean \
    && make install \
    && rm -rf $HOME/librealsense

########################################################
# final steps
########################################################
RUN apt-get upgrade -qy \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/*

COPY in_container_scripts/mod_bashrc.sh $HOME
RUN ./mod_bashrc.sh && rm mod_bashrc.sh

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

# necessary to make all installed libraries available for linking
RUN ldconfig

# start ssh daemon
CMD ["/usr/sbin/sshd", "-D"]
