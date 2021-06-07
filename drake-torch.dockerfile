ARG BASE_IMAGE
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

# setup timezone
RUN echo 'etc/UTC' > /etc/timezone \
    && ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime

# prerequisites for install other apt packages (GPG, keys, cert...)
# set up apt for installing latest cmake, which is a drake dependency
RUN apt-get update \
    && apt-get install -qy \
        apt-utils \
        apt-transport-https \
        software-properties-common \
        curl \
        wget

# Set debconf to noninteractive mode
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
ARG DEBIAN_FRONTEND=noninteractive

# apt repo, keyring for cmake
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null \
    && add-apt-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -sc) main" \
    && apt-get install -qy kitware-archive-keyring \
    && rm /etc/apt/trusted.gpg.d/kitware.gpg 

# apt repo for latest gcc toolchain
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test

# install gcc-10, cmake, python3 etc.
RUN apt-get update \
    && apt-get install -qy \
        cmake \
        unzip \
        python3 \
        python3-dev \
        python3-pip \
        # gcc7 for libfranka
        gcc-7 \
        g++-7 \
        gcc-10 \
        g++-10 \
        gcc-11 \
        g++-11

RUN update-alternatives \
        --install /usr/bin/gcc gcc /usr/bin/gcc-11 90 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-11 \
        --slave /usr/bin/gcov gcov /usr/bin/gcov-11

RUN python3 -m pip install --upgrade --no-cache-dir --compile \
        setuptools wheel pip

# install make 4.3
RUN curl -SL https://ftp.gnu.org/gnu/make/make-4.3.tar.gz | tar -xz \
    && cd make-4.3 \
    && mkdir build \
    && cd build \
    && ../configure --prefix=/usr \
    && make --quiet -j 12 \
    && make --quiet install \
    && cd $HOME \
    && rm -rf make-4.3

# install latest googletest 
# googletest 1.10.0 including googlemock
# do not delete yet because will need to re-install after ROS
# RUN if [ $BUILD_CHANNEL = 'stable' ]; then \
#         curl -SL https://github.com/google/googletest/archive/release-1.10.0.tar.gz | tar -xz \
#         && cd googletest-release-1.10.0 \
#         && mkdir build \
#         && cd build \
#         && cmake .. \
#         && make install -j 12; \
#     fi
RUN apt-get install -qy googletest

# install latest gdb
# texinfo is needed for building gdb 9.2 even in the presence of make 4.3
# RUN if [ $BUILD_CHANNEL = 'stable' ]; then \
#         apt-get install texinfo -qy \
#         && curl -SL https://ftp.gnu.org/gnu/gdb/gdb-10.2.tar.xz | tar -xJ \
#         && cd gdb-10.2 \
#         && mkdir build \
#         && cd build \
#         && ../configure \
#             --prefix=/usr \
#             # --with-system-readline \
#             --with-python=/usr/bin/python3 \
#         && make --quiet -j 12 \
#         && make --quiet install \
#         && cd $HOME \
#         && rm -rf gdb*
RUN apt-get install -qy gdb

# install latest ninja
RUN wget https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-linux.zip \
    && unzip ninja-linux.zip \
    && mv ninja /usr/bin/ \
    && rm ninja-linux.zip

# intel OneAPI base, including MKL
RUN wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    && apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    && rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    && add-apt-repository "deb https://apt.repos.intel.com/oneapi all main" \
    && apt-get install -qy intel-basekit

##############################################################
# libtorch and pytorch, torchvision
##############################################################

ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.5 8.0+PTX"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV BUILD_CAFFE2_OPS=1
ENV _GLIBCXX_USE_CXX11_ABI=1

RUN set -eux && cd $HOME \
    && \
        if [ $BUILD_TYPE = "cpu" ]; then \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                wget -q https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-1.8.1%2Bcpu.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile torch==1.8.1+cpu torchvision==0.9.1+cpu -f https://download.pytorch.org/whl/torch_stable.html; \
            else \
                wget -q https://download.pytorch.org/libtorch/nightly/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html; \
            fi; \
        else \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                wget -q https://download.pytorch.org/libtorch/cu111/libtorch-cxx11-abi-shared-with-deps-1.8.1%2Bcu111.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile torch==1.8.1+cu111 torchvision==0.9.1+cu111 -f https://download.pytorch.org/whl/torch_stable.html; \
            else \
                wget -q https://download.pytorch.org/libtorch/nightly/cu111/libtorch-cxx11-abi-shared-with-deps-latest.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cu111/torch_nightly.html; \
            fi; \
        fi \
    && unzip libtorch-cxx11-abi-shared-with-deps-*.zip \
    && mv libtorch /usr/local/lib/libtorch \
    && rm $HOME/libtorch*.zip

########################################################
# drake
# https://drake.mit.edu/from_binary.html
# https://github.com/RobotLocomotion/drake/releases

# https://drake-packages.csail.mit.edu/drake/nightly/drake
# https://drake-packages.csail.mit.edu/drake/nightly/drake-20200602-focal.tar.gz

########################################################
RUN set -eux \
    && mkdir -p /opt \
    && \
        if [ $BUILD_CHANNEL = "stable" ] ; \
        then curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-focal.tar.gz | tar -xzC /opt; \
        else curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-focal.tar.gz | tar -xzC /opt; \
        fi \
    && cd /opt/drake/share/drake/setup && yes | ./install_prereqs \
    && rm -rf $HOME/drake*.tar.gz

# pip install pydrake using the /opt/drake directory in develop mode
COPY in_container_scripts/setup_pydrake.py setup_pydrake.py
RUN if [ "`lsb_release -sc`" = "bionic" ]; \
    then mv setup_pydrake.py /opt/drake/lib/python3.6/site-packages/setup.py \
        && python3 -m pip install -e /opt/drake/lib/python3.6/site-packages; \
    else mv setup_pydrake.py /opt/drake/lib/python3.8/site-packages/setup.py \
        && python3 -m pip install -e /opt/drake/lib/python3.8/site-packages; \
    fi

# get rid of the following spam
# FindResource ignoring DRAKE_RESOURCE_ROOT because it is not set.
RUN echo 'export DRAKE_RESOURCE_ROOT=/opt/drake/share' >> ~/.bashrc 

# drake installs some python packages as dependencies, causing jupyter issues
RUN apt remove python3-zmq python3-terminado python3-yaml -qy \
    && python3 -m pip install \
        --upgrade --no-cache-dir --compile \
        ipython ipykernel jupyterlab matplotlib cython pyyaml

# install latest eigen3
RUN curl -SL https://gitlab.com/libeigen/eigen/-/archive/3.4-rc1/eigen-3.4-rc1.tar.bz2 | tar -xj \
    && cd eigen-3.4-rc1 \
    && mkdir build \
    && cd build \
    && cmake build .. -D CMAKE_INSTALL_PREFIX=/usr/local \
    && make install -j 12 \
    && rm -rf $HOME/eigen*

RUN apt-get update \
    && apt-get upgrade -qy \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/*
