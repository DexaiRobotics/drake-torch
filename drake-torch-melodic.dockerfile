ARG BASE_IMAGE
FROM $BASE_IMAGE
USER root
WORKDIR /root

# Set debconf to noninteractive mode
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -qy

# install latest eigen3
RUN curl -SL https://gitlab.com/libeigen/eigen/-/archive/3.3.7/eigen-3.3.7.tar.bz2 | tar -xj \
    && cd eigen-3.3.7 \
    && mkdir build \
    && cd build \
    && cmake build .. -D CMAKE_INSTALL_PREFIX=/usr/local \
    && make install \
    && rm -rf $HOME/eigen-3.3.7

# OpenCV 4.4.0 for C++ and Python3 before ROS
RUN apt-get install -qy \
        python3-numpy \
        libgtk-3-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev \
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

RUN apt-get update && apt-get install -qy \
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
    ros-melodic-gazebo-ros \
    ros-melodic-rviz \
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

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# install ros packages
ENV ROS_DISTRO melodic
RUN apt-get install -qy \
        python-catkin-tools \
        usbutils \
        iputils-ping

# # install cv_bridge to /opt/ros/melodic from source
# # --install-layout is a debian modification to Pythons "distutils" module.
# # That option is maintained by and only shipped with Debian(-derivates). 
# # It is not part of the official Python release (PyPI).
# # so we need pass a cmake flag SETUPTOOLS_DEB_LAYOUT=OFF.
# # try SETUPTOOLS_USE_DISTUTILS=stdlib instead

# SHELL ["/bin/bash", "-c"]
# RUN cd $HOME && mkdir -p py3_ws/src && cd py3_ws/src \
#     && git clone -b melodic https://github.com/DexaiRobotics/vision_opencv.git \
#     && git clone -b melodic-devel https://github.com/ros/ros_comm.git \
#     && cd $HOME/py3_ws \
#     && python3 -m pip install --upgrade --no-cache-dir --compile \
#         catkin_tools \
#         pycryptodomex \
#         gnupg \
#     && source /opt/ros/melodic/setup.bash \
#     && export ROS_PYTHON_VERSION=3 \
#     && catkin config --install \
#         --install-space /opt/ros/melodic \
#         --cmake-args \
#             -D PYTHON_EXECUTABLE=/usr/bin/python3 \
#             -D PYTHON_INCLUDE_DIR=/usr/include/python3.6m \
#             -D PYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.6m.so \
#             -D OPENCV_VERSION_MAJOR=4 \
#             -D CMAKE_BUILD_TYPE=Release \
#             # -D SETUPTOOLS_DEB_LAYOUT=OFF \
#     && catkin build && rm -rf $HOME/py3_ws

# reinstall opencv 4 to fix symlinks
RUN cd $HOME/opencv-4.4.0/build \
    && make install \
    && cd $HOME \
    && rm -rf opencv-4.4.0

########################################################
# other dexai stack dependencies
########################################################

# Install C++ branch of msgpack-c
RUN cd $HOME && git clone -b cpp_master https://github.com/msgpack/msgpack-c.git \
    && cd msgpack-c && cmake -DMSGPACK_CXX17=ON . && make install -j 12 \
    && cd $HOME && rm -rf msgpack-c

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

# qpOASES
RUN cd $HOME && git clone https://github.com/hungpham2511/qpOASES $HOME/qpOASES \
    && cd $HOME/qpOASES/ && mkdir -p bin && make -j 12 \
    && cd $HOME/qpOASES/interfaces/python/ && python3 setup.py install \
    && rm -rf $HOME/qpOASES

# toppra: Dexai fork
RUN cd $HOME && git clone https://github.com/DexaiRobotics/toppra \
    && python3 -m pip install --upgrade --no-cache-dir --compile ./toppra \
    && rm -rf toppra

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
RUN apt-get install -qy \
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
    && apt-get upgrade -qy \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/*

RUN git lfs install

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

# start ssh daemon
CMD ["/usr/sbin/sshd", "-D"]
