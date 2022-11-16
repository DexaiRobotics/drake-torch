ARG BASE_IMAGE
FROM $BASE_IMAGE
USER root
WORKDIR /root
ARG BUILD_TYPE
ARG LIBTORCH
ARG BUILD_CHANNEL
RUN echo "Oh dang look at that BUILD_TYPE=${BUILD_TYPE}"
RUN echo "Oh dang look at that BUILD_CHANNEL=${BUILD_CHANNEL}"

########################################################
# initial setup
########################################################

# Remove apt repos that came with the base nvidia docker image.
# https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64
# https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu2004/x86_64
# They are either unreliable or have been deprecated.
# They only exist in the CUDA image, not the CPU one.
RUN rm -f /etc/apt/sources.list.d/cuda.list /etc/apt/sources.list.d/nvidia-ml.list

# setup timezone
RUN echo 'etc/UTC' > /etc/timezone \
    && ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime

# prerequisites for install other apt packages (GPG, keys, cert...)
# set up apt for installing latest cmake, which is a drake dependency
RUN apt-get update \
    && apt-get install -qy \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-utils \
        apt-transport-https \
        software-properties-common \
        curl \
        wget

# Set debconf to noninteractive mode
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
ARG DEBIAN_FRONTEND=noninteractive

# apt repo, keyring for cmake
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null \
    # && add-apt-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -sc) main" \
    && echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null \
    && apt-get update \
    && rm /usr/share/keyrings/kitware-archive-keyring.gpg \
    && apt-get install -qy kitware-archive-keyring

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
        python3-venv \
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

# create venv to avoid site breakage between debian and pip
RUN python3 -m venv /opt/venv \
    && ln -s  /opt/venv/bin/activate /usr/local/bin/activate \
    && . activate \
    && pip install --upgrade --no-cache-dir --compile \
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

# occasionally GNU make does not resolve dependency tree of targets correctly
# and fails to build with multiple threads. Ninja hasn't been observed to suffer
# the same issue, so we set it as the default generator for cmake.
ENV CMAKE_GENERATOR=Ninja

##############################################################
# libtorch and pytorch, torchvision
##############################################################

ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.5 8.0+PTX"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV BUILD_CAFFE2_OPS=1
ENV _GLIBCXX_USE_CXX11_ABI=1

RUN set -eux && cd $HOME \
    && . activate \
    && \
        if [ $LIBTORCH = true ]; then \
            if [ $BUILD_TYPE = "cpu" ]; then \
                if [ $BUILD_CHANNEL = "stable" ]; then \
                    wget -q https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-1.12.1%2Bcpu.zip; \
                else \
                    wget -q https://download.pytorch.org/libtorch/nightly/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip; \
                fi; \
            else \
                if [ $BUILD_CHANNEL = "stable" ]; then \
                    wget -q https://download.pytorch.org/libtorch/cu116/libtorch-cxx11-abi-shared-with-deps-1.12.1%2Bcu116.zip; \
                else \
                    wget -q https://download.pytorch.org/libtorch/nightly/cu116/libtorch-cxx11-abi-shared-with-deps-latest.zip; \
                fi; \
            fi \
            && unzip libtorch-cxx11-abi-shared-with-deps-*.zip \
            && mv libtorch /usr/local/lib/libtorch \
            && rm $HOME/libtorch*.zip; \
        fi \
    && \
        if [ $BUILD_TYPE = "cpu" ]; then \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                python3 -m pip install --upgrade --no-cache-dir --compile torch==1.12.1 torchvision==0.13.1 --extra-index-url https://download.pytorch.org/whl/cpu; \
            else \
                python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision --extra-index-url https://download.pytorch.org/whl/nightly/cpu; \
            fi; \
        else \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                python3 -m pip install --upgrade --no-cache-dir --compile torch==1.12.1 torchvision==0.13.1 --extra-index-url https://download.pytorch.org/whl/cu116 \
                && python3 -m pip install torch-scatter --upgrade --no-cache-dir --compile -f https://data.pyg.org/whl/torch-1.12.0+cu116.html; \
            else \
                # do not install torch-scatter here because it will segfault with nightly torch
                python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision --extra-index-url https://download.pytorch.org/whl/nightly/cu116/torch_nightly.html; \
            fi; \
        fi

# install latest eigen3
RUN curl -SL https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.bz2 | tar -xj \
    && cd eigen-3.4.0 \
    && mkdir build \
    && cmake -S . -B build -D CMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -j 12 \
    && cmake --install build --prefix=/usr/local \
    && rm -rf $HOME/eigen*

# install latest fmt (to be compatible with latest spdlog)
# TODO: upgrade to 9.1.0+ after upgrading drake
RUN curl -SL https://github.com/fmtlib/fmt/archive/refs/tags/8.1.1.tar.gz | tar xz \
    && cd fmt-8.1.1 \
    && mkdir build \
    && cmake -S . -B build -D CMAKE_BUILD_TYPE=Release -D BUILD_SHARED_LIBS=ON \
    && cmake --build build --config Release -j 12 \
    && cmake --install build \
    && rm -rf $HOME/fmt*

########################################################
# drake
# https://drake.mit.edu/from_binary.html
# https://github.com/RobotLocomotion/drake/releases

# https://drake-packages.csail.mit.edu/drake/nightly/drake
# https://drake-packages.csail.mit.edu/drake/nightly/drake-20200602-focal.tar.gz

# stable channel pegged to (0.33.0-1) 20210811 due to collision filter group changes
# the apt binaries are more optimised and run faster than the gz

########################################################
RUN set -eux \
    && mkdir -p /opt \
    && . activate \
    && \
        # if [ $BUILD_CHANNEL = "stable" ]; then \
        #     wget -qO- https://drake-apt.csail.mit.edu/drake.asc | gpg --dearmor - \
        #         | tee /etc/apt/trusted.gpg.d/drake.gpg >/dev/null \
        #     && echo "deb [arch=amd64] https://drake-apt.csail.mit.edu/$(lsb_release -cs) $(lsb_release -cs) main" \
        #         | tee /etc/apt/sources.list.d/drake.list >/dev/null \
        #     && apt-get update \
        #     && apt-get install --no-install-recommends -qy drake-dev; \
        if [ $BUILD_CHANNEL = "stable" ]; then \
            curl -SL https://github.com/RobotLocomotion/drake/releases/download/v1.10.0/drake-dev_1.10.0-1_amd64-focal.deb \
            && dpkg -i drake-dev_1.10.0-1_amd64-focal.deb \
            && rm -rf $HOME/drake*.deb; \
        else \
            curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-focal.tar.gz | tar -xzC /opt \
            && cd /opt/drake/share/drake/setup \
            && yes | ./install_prereqs \
            && rm -rf $HOME/drake*.tar.gz; \
        fi

# pip install pydrake using the /opt/drake directory in develop mode
# --user flag is broken for editable install right now, at least with setuptools backend
COPY in_container_scripts/setup_pydrake.py setup_pydrake.py
RUN . activate \
    && \
        if [ "`lsb_release -sc`" = "bionic" ]; \
        then mv setup_pydrake.py /opt/drake/lib/python3.6/site-packages/setup.py \
            && python3 -m pip install -e /opt/drake/lib/python3.6/site-packages; \
        else mv setup_pydrake.py /opt/drake/lib/python3.8/site-packages/setup.py \
            && python3 -m pip install -e /opt/drake/lib/python3.8/site-packages; \
        fi

# get rid of the following spam
# FindResource ignoring DRAKE_RESOURCE_ROOT because it is not set.
RUN echo 'export DRAKE_RESOURCE_ROOT=/opt/drake/share' >> ~/.bashrc 

# install latest spdlog (only 1.5 from apt installed by drake)
# we build static lib because libspdlog-dev that ships with ubuntu is shared
# and located in /usr
# if we have another shared lib installed into any system path (/usr/local)
# drake crashes
# including two shared libs causes cmake errors, so we keep this one static
# CMAKE_POSITION_INDEPENDENT_CODE adds -fPIC so that our .so can borrow from .a
# Also external fmt is a pain to set up and use by dependent applications
# https://github.com/gabime/spdlog/issues/2310
# TODO: upgrade to 1.10.0+ after upgrading drake
RUN curl -SL https://github.com/gabime/spdlog/archive/refs/tags/v1.10.0.tar.gz | tar xz \
    && cd spdlog-1.10.0 \
    && mkdir build \
    && cmake -S . -B build \
        # -D SPDLOG_FMT_EXTERNAL=ON \
        -D CMAKE_BUILD_TYPE=Release \
        -D BUILD_SHARED_LIBS=OFF \
        -D CMAKE_POSITION_INDEPENDENT_CODE=ON \
    && cmake --build build --config Release -j 12 \
    && cmake --install build --prefix=/usr/local \
    && rm -rf $HOME/spdlog*
