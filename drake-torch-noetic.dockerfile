ARG BASE_IMAGE
FROM $BASE_IMAGE
USER root
WORKDIR /root
ARG BUILD_TYPE

# Set debconf to noninteractive mode
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -qy

# OMPL fist as compiling is slow
RUN wget https://ompl.kavrakilab.org/install-ompl-ubuntu.sh \
    && chmod +x install-ompl-ubuntu.sh \
    && ./install-ompl-ubuntu.sh --python \
    && rm -rf /usr/local/include/ompl $HOME/ompl-1.5.2 $HOME/castxml \
    && ln -s /usr/local/include/ompl-1.5/ompl /usr/local/include/ompl \
    && rm install-ompl-ubuntu.sh

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
    ros-noetic-apriltag-ros \
    # ros-noetic-gazebo-ros \
    ros-noetic-async-web-server-cpp \
    ros-noetic-realsense2-camera \
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
        usbutils
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

# OpenCV for C++ and Python3
RUN apt-get install -qy \
        libgtk-3-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev \
        libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev \
    && apt-get autoremove -qy
RUN curl -SL https://github.com/opencv/opencv/archive/refs/tags/4.5.2.tar.gz | tar -xz
RUN cd opencv-4.5.2 \
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

# install cli11
RUN cd $HOME && curl -SL https://github.com/CLIUtils/CLI11/archive/refs/tags/v1.9.1.tar.gz | tar -xz \
    && cd CLI11-1.9.1 \
    && mkdir build \
    && cd build \
    && cmake .. \
        -D CMAKE_BUILD_TYPE=Release \
        -D CLI11_SINGLE_FILE=OFF \
        -D CLI11_BUILD_DOCS=OFF \
        -D CLI11_BUILD_TESTS=OFF \
        -D CLI11_BUILD_EXAMPLES=OFF \
    && make install -j 12 \
    && cd .. \
    && rm -rf CLI11-1.9.1

# install json, header only
RUN wget https://github.com/nlohmann/json/releases/download/v3.9.1/json.hpp -P /usr/local/include/

# install magic_enum, header only
RUN wget https://github.com/Neargye/magic_enum/releases/download/v0.7.2/magic_enum.hpp -P /usr/local/include/

# insall ctpl thread pool, header only
RUN cd $HOME \
    && curl -SL https://github.com/vit-vit/CTPL/archive/refs/tags/v.0.0.2.tar.gz | tar -xz \
    && cp CTPL-v.0.0.2/ctpl*.h /usr/local/include/ \
    && rm -rf CTPL-v.0.0.2

# Install C++ branch of msgpack-c
RUN cd $HOME && git clone -b cpp_master https://github.com/msgpack/msgpack-c.git \
    && cd msgpack-c && cmake -DMSGPACK_CXX17=ON . && make install -j 12 \
    && cd $HOME && rm -rf msgpack-c

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

# RUN apt-key adv \
#         --keyserver keys.gnupg.net \
#         --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE \
#         || sudo apt-key adv \
#         --keyserver hkp://keyserver.ubuntu.com:80 \
#         --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE \
#     && add-apt-repository "deb https://librealsense.intel.com/Debian/apt-repo focal main" -u \
#     && apt-get install -qy \
#         librealsense2-dkms \
#         librealsense2-utils \
#         librealsense2-dev \
#         librealsense2-dbg \
#         librealsense2 \
#         ros-noetic-librealsense2

########################################################
# final steps
########################################################
RUN apt-get upgrade -qy \
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

# start ssh daemon
CMD ["/usr/sbin/sshd", "-D"]
