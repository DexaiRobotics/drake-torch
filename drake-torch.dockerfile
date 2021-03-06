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

# apt repo for gcc-10
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test

# install gcc-10, cmake, python3 etc.
RUN apt-get update \
    && apt-get install -qy \
        cmake \
        unzip \
        python3 \
        python3-dev \
        python3-pip \
    && \
        if [ $BUILD_CHANNEL = 'stable' ]; then \
            apt-get install -qy gcc-8 g++-8 gcc-10 g++-10; \
        else \
            apt-get install -qy gcc-9 g++-9 gcc-10 g++-10; \
        fi

RUN update-alternatives \
        --install /usr/bin/gcc gcc /usr/bin/gcc-10 90 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-10 \
        --slave /usr/bin/gcov gcov /usr/bin/gcov-10

RUN python3 -m pip install --upgrade --no-cache-dir --compile \
        setuptools wheel pip

# googletest 1.10.0 including googlemock
# do not delete yet because will need to re-install after ROS
RUN if [ $BUILD_CHANNEL = 'stable' ]; then \
        curl -SL https://github.com/google/googletest/archive/release-1.10.0.tar.gz | tar -xz \
        && cd googletest-release-1.10.0 \
        && mkdir build \
        && cd build \
        && cmake .. \
        && make install -j 12; \
    fi

# install make 4.3 and GDB 9.2
RUN curl -SL https://ftp.gnu.org/gnu/make/make-4.3.tar.gz | tar -xz \
    && cd make-4.3 \
    && mkdir build \
    && cd build \
    && ../configure --prefix=/usr \
    && make --quiet -j 12 \
    && make --quiet install \
    && cd $HOME \
    && rm -rf make-4.3
# texinfo is needed for building gdb 9.2 even in the presence of make 4.3
RUN if [ $BUILD_CHANNEL = 'stable' ]; then \
        apt-get install texinfo -qy \
        && curl -SL https://ftp.gnu.org/gnu/gdb/gdb-9.2.tar.xz | tar -xJ \
        && cd gdb-9.2 \
        && mkdir build \
        && cd build \
        && ../configure \
            --prefix=/usr \
            # --with-system-readline \
            --with-python=/usr/bin/python3 \
        && make --quiet -j 12 \
        && make --quiet install \
        && cd $HOME \
        && rm -rf gdb-9.2; \
    fi

##############################################################
# libtorch and pytorch, torchvision with intel MKL support
##############################################################

RUN wget -q https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
RUN apt-key add --no-tty GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && rm GPG-PUB*
RUN sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list'
RUN apt-get update && apt-get -qy install intel-mkl-64bit-2020.0-088
RUN rm /opt/intel/mkl/lib/intel64/*.so

# Download and build libtorch with MKL support
ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.5"
ENV TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
ENV BUILD_CAFFE2_OPS=1
ENV _GLIBCXX_USE_CXX11_ABI=1

RUN set -eux && cd $HOME \
    && \
        if [ $BUILD_TYPE = "cpu" ]; then \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                wget -q https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-1.7.0%2Bcpu.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile torch==1.7.0+cpu torchvision==0.8.1+cpu -f https://download.pytorch.org/whl/torch_stable.html; \
            else \
                wget -q https://download.pytorch.org/libtorch/nightly/cpu/libtorch-cxx11-abi-shared-with-deps-latest.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html; \
            fi; \
        else \
            if [ $BUILD_CHANNEL = "stable" ]; then \
                wget -q https://download.pytorch.org/libtorch/cu110/libtorch-cxx11-abi-shared-with-deps-1.7.0%2Bcu110.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile torch torchvision; \
            else \
                wget -q https://download.pytorch.org/libtorch/nightly/cu110/libtorch-cxx11-abi-shared-with-deps-latest.zip \
                && python3 -m pip install --upgrade --no-cache-dir --compile --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cu102/torch_nightly.html; \
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
        then curl -SL https://drake-packages.csail.mit.edu/drake/nightly/drake-latest-bionic.tar.gz | tar -xzC /opt; \
        # TODO: @dyt change date below to latest after removing RBT dependencies
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

# drake installs some python packages as dependencies, causing jupyter issues
RUN apt remove python3-zmq python3-terminado -qy \
    && python3 -m pip install \
        --upgrade --no-cache-dir --compile \
        ipython ipykernel jupyterlab matplotlib

# install the latest libboost
RUN apt-get purge -qy libboost* \
    && apt-get autoremove -qy
RUN add-apt-repository -y ppa:mhier/libboost-latest \
    && apt-get install -qy libboost1.74-dev

# install latest eigen3
RUN curl -SL https://gitlab.com/libeigen/eigen/-/archive/3.3.9/eigen-3.3.9.tar.bz2 | tar -xj \
    && cd eigen-3.3.9 \
    && mkdir build \
    && cd build \
    && cmake build .. -D CMAKE_INSTALL_PREFIX=/usr/local \
    && make install -j 12 \
    && rm -rf $HOME/eigen-3.3.9

RUN apt-get update \
    && apt-get upgrade -qy \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/*
