ARG BASE_IMAGE
FROM $BASE_IMAGE
USER root
WORKDIR /root
ARG BUILD_TYPE

# Set debconf to noninteractive mode
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -qy

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
# add env var to specify ROS distro
ENV ROS_DISTRO=noetic
ENV ROS_PYTHON_VERSION=3

RUN apt-get update && apt-get install -qy \
    ros-noetic-ros-base \
    ros-noetic-geometry2 \
    ros-noetic-pcl-ros \
    ros-noetic-vision-opencv \
    ros-noetic-xacro \
    ros-noetic-rospy-message-converter \
    ros-noetic-image-transport \
    ros-noetic-rgbd-launch \
    ros-noetic-ddynamic-reconfigure \
    ros-noetic-diagnostic-updater \
    ros-noetic-robot-state-publisher \
    ros-noetic-joint-state-publisher \
    ros-noetic-tf-conversions \
    ros-noetic-rviz \
    ros-noetic-rqt \
    ros-noetic-apriltag \
    ros-noetic-joy \
    ros-noetic-roslint \
    # ros-noetic-gazebo-ros \
    ros-noetic-async-web-server-cpp \
    ros-noetic-realsense2-camera \
    ros-noetic-realsense2-description \
    # catkin tools nad osrf from pip doesn't work for py3 and focal/noetic
    # https://github.com/catkin/catkin_tools/issues/594
    python3-catkin-tools \
    python3-osrf-pycommon

# dev essentials, later sections need git
RUN add-apt-repository -y ppa:git-core/ppa \
    && apt-get install -qy \
        openssh-server \
        openssh-client \
        iputils-ping \
        vim \
        nano \
        cron \
        git \
        git-extras \
        git-lfs \
        tig \
        htop \
        screen \
        xvfb \
        fluxbox \
        x11vnc \
        tmux \
        tree \
        doxygen \
        libgflags-dev \
        # libusb needed by HID API and librealsense
        libusb-1.0-0-dev \
        # libudev are both needed by HID API
        libudev-dev \
        usbutils \
        # needed to build spacenav_node in
        # ros package joystick_drivers which
        # is used to interface with joystick
        # for teleop
        libspnav-dev \
        # for parsing json and coveralls
        jq \
        ffmpeg \
        # for nonblocking processes when sharing same root shell
        parallel \
    && python3 -m pip install --upgrade --no-cache-dir --compile cpplint gcovr GitPython
RUN rm /etc/alternatives/editor \
    && ln -s /usr/bin/vim /etc/alternatives/editor
RUN git lfs install

# build catkin modules not availble via apt
# SHELL ["/bin/bash", "-c"]
RUN mkdir -p temp_ws/src \
    && cd temp_ws/src \
    && git clone https://github.com/RobotWebTools/web_video_server \
    && cd $HOME/temp_ws \
    && bash -c \
        "source /opt/ros/$ROS_DISTRO/setup.bash \
        && catkin config --install --install-space /opt/ros/noetic \
        && catkin build --cmake-args -DCMAKE_BUILD_TYPE=Release \
        && rm -rf $HOME/temp_ws"

########################################################
#### newer packages
########################################################

# install latest googletest 1.11.0 including googlemock
RUN curl -SL https://github.com/google/googletest/archive/release-1.11.0.tar.gz | tar -xz \
    && cd googletest-release-1.11.0 \
    && mkdir build \
    && cd build \
    && cmake .. -D CMAKE_BUILD_TYPE=Release \
    && make install -j 12 \
    && cd $HOME \
    && rm -rf googletest*

# OpenCV for C++ and Python3
# opencv 4.5.4 gets segfault in cv::resize
RUN apt-get install -qy \
        libgtk-3-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev \
        libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev \
    && apt-get autoremove -qy
RUN curl -SL https://github.com/opencv/opencv/archive/refs/tags/4.5.3.tar.gz | tar -xz
RUN cd opencv-4.5.3 \
    && mkdir build \
    && cd build \
    && cmake .. \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D PYTHON3_EXECUTABLE=/usr/bin/python3 \
        -D PYTHON_INCLUDE_DIR=/usr/include/python3.8 \
        -D PYTHON_INCLUDE_DIR2=/usr/include/x86_64-linux-gnu/python3.8 \
        -D PYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.8.so \
        -D PYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include \
    && make install -j 12 \
    && cd $HOME \
    && rm -rf opencv*

########################################################
# other dependencies
########################################################

# OMPL official installer
# RUN wget https://ompl.kavrakilab.org/install-ompl-ubuntu.sh \
#     && chmod +x install-ompl-ubuntu.sh \
#     && ./install-ompl-ubuntu.sh --python \
#     && rm -rf $HOME/ompl-1.5.2 $HOME/castxml \
#     && rm install-ompl-ubuntu.sh

# build OMPL fork from source 
# make -j 4 update_bindings # if you want Python bindings
RUN git clone https://github.com/DexaiRobotics/ompl.git \
    && cd ompl \
    && mkdir -p build \
    && cmake -S . -B build -D CMAKE_BUILD_TYPE=Release \
    && cmake --build build -j 10 \
    && cd build \
    && make install -j 10 \
    && rm -rf $HOME/ompl

# install cli11
RUN cd $HOME && curl -SL https://github.com/CLIUtils/CLI11/archive/refs/tags/v2.1.2.tar.gz | tar -xz \
    && cd CLI11-2.1.2 \
    && mkdir build \
    && cd build \
    && cmake .. \
        -D CMAKE_BUILD_TYPE=Release \
        -D CLI11_SINGLE_FILE=OFF \
        -D CLI11_BUILD_DOCS=OFF \
        -D CLI11_BUILD_TESTS=OFF \
        -D CLI11_BUILD_EXAMPLES=OFF \
    && make install -j 12 \
    && rm -rf $HOME/CLI11*

# install json, header only
RUN wget https://github.com/nlohmann/json/releases/download/v3.10.4/json.hpp -P /usr/local/include/

# install magic_enum, header only
RUN wget https://github.com/Neargye/magic_enum/releases/download/v0.7.3/magic_enum.hpp -P /usr/local/include/

# tl::optional, enhanced version of std::optional, header only
RUN mkdir -p /usr/local/include/tl \
  && wget https://github.com/TartanLlama/optional/raw/master/include/tl/optional.hpp -P /usr/local/include/tl

# tl::expected, header only
RUN wget https://github.com/TartanLlama/expected/raw/master/include/tl/expected.hpp -P /usr/local/include/tl

# eventpp, a header-only event dispatch and callback library
RUN cd $HOME \
    && git clone https://github.com/wqking/eventpp.git \
    && cp -R eventpp/include/eventpp /usr/local/include/ \
    && rm -rf eventpp

# insall ctpl thread pool, header only
RUN cd $HOME \
    && curl -SL https://github.com/vit-vit/CTPL/archive/refs/tags/v.0.0.2.tar.gz | tar -xz \
    && cp CTPL-v.0.0.2/ctpl*.h /usr/local/include/ \
    && rm -rf CTPL-v.0.0.2

RUN cd $HOME \
    && wget https://github.com/approvals/ApprovalTests.cpp/releases/download/v.10.12.0/ApprovalTests.v.10.12.0.hpp -O /usr/local/include/ApprovalTests.hpp

# Install C++ branch of msgpack-c
RUN cd $HOME && git clone -b cpp_master https://github.com/msgpack/msgpack-c.git \
    && cd msgpack-c && cmake -DMSGPACK_CXX17=ON . && make install -j 12 \
    && cd $HOME && rm -rf msgpack-c

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

# install botcore lcmtypes for parsing data in these formats in python
# this package is owned by https://github.com/openhumanoids and MIT DRC
RUN git clone https://github.com/openhumanoids/bot_core_lcmtypes.git \
    && cd bot_core_lcmtypes \
    && lcm-gen -p lcmtypes/*.lcm \
    && mv bot_core /usr/local/lib/python3.8/dist-packages/ \
    && cd $HOME && rm -rf bot_core_lcmtypes

# install librealsense2-utils for realsense viewer
# librealsense2-udev-rules:amd64 requires rsync
RUN apt-key adv --keyserver keyserver.ubuntu.com \
        --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE\
        || apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
        --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCD \
    && add-apt-repository "deb https://librealsense.intel.com/Debian/apt-repo $(lsb_release -cs) main" -u \
    && apt-get install -qy \
        rsync \
        # librealsense2 \
        # librealsense2-dkms \
        # librealsense2-dev \
        # librealsense2-dbg \
        librealsense2-utils

# linters

# clang-format, clang-tidy
RUN wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - 2>/dev/null \
    && add-apt-repository "deb http://apt.llvm.org/`lsb_release -sc`/ llvm-toolchain-`lsb_release -sc` main" 2>/dev/null \
    && apt-get -qy install clang-format-14 clang-tidy-14 \
    && ln -s /usr/bin/clang-format-14 /usr/bin/clang-format \
    && ln -s /usr/bin/clang-tidy-14 /usr/bin/clang-tidy

# oclint
RUN curl -SL https://github.com/oclint/oclint/archive/refs/tags/v21.05.tar.gz | tar xz \
    && cd oclint-21.05/oclint-scripts/ \
    && ./make \
    && cd ../build/oclint-release/ \
    && cp bin/oclint /usr/local/bin/ \
    && cp -rp lib/oclint /usr/local/lib/ \
    && cd $HOME \
    && rm -rf oclint*

# cppcheck
# curl -SL https://github.com/danmar/cppcheck/archive/refs/tags/2.5.tar.gz | tar xz \
#     && cd cppcheck-2.5/ \
RUN git clone https://github.com/danmar/cppcheck.git \
    && cd cppcheck \
    && mkdir build \
    && cd build \
    && cmake .. -DUSE_MATCHCOMPILER=ON -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . --config Release -j 10 \
    && make install \
    && cd $HOME \
    && rm -rf cppcheck

########################################################
# final steps
########################################################
RUN apt-get update \
    && apt-get upgrade -qy \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/*

COPY in_container_scripts scripts
RUN scripts/mod_bashrc.sh && rm -rf scripts

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

# necessary to make all installed libraries available for linking
RUN ldconfig

# increase max_user_watches limits
RUN echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf

# set core pattern to bypass apport
# essentially modifies /proc/sys/kernel/core_pattern
RUN ulimit -c unlimited \
    && sysctl -w kernel.core_pattern=/var/crash/core.%e.%p.%h.%t

# start ssh daemon
CMD ["/usr/sbin/sshd", "-D"]
