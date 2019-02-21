#!/bin/bash
#   Installs OMPL (libompl) and some pre-requisites system-wide on Ubuntu (not on Mac).
#   Run as superuser:
#       bash$ sudo ./install_ompl_ubuntu_1.3.2.sh

ubuntu_version=`lsb_release -rs | sed 's/\.//'`

install_common_dependencies()
{
    # install most dependencies via apt-get
    apt-get -y update
    apt-get -y upgrade
    # On Ubuntu 14.04 we need to add a PPA to get a recent compiler (g++-4.8 is too old).
    # We also need to specify a Boost version, since the default Boost is too old.
    #
    # We explicitly set the C++ compiler to g++, the default GNU g++ compiler. This is
    # needed because we depend on system-installed libraries built with g++ and linked
    # against libstdc++. In case `c++` corresponds to `clang++`, code will not build, even
    # if we would pass the flag `-stdlib=libstdc++` to `clang++`.
    if [[ $ubuntu_version > 1410 ]]; then
        apt-get -y install cmake pkg-config libboost-all-dev libeigen3-dev libode-dev
        export CXX=g++
    else
        # needed for the add-apt-repository command, which was not part of early Trusty releases
        apt-get -y install software-properties-common
        add-apt-repository -y ppa:ubuntu-toolchain-r/test
        apt-get -y update
        apt-get -y install g++-5 cmake pkg-config libboost1.55-all-dev libeigen3-dev libode-dev
        export CXX=g++-5
    fi
    export MAKEFLAGS="-j `nproc`"
}

install_python_binding_dependencies()
{
    apt-get -y install python${PYTHONV}-dev python${PYTHONV}-pip
    # install additional python dependencies via pip
    pip${PYTHONV} install -vU pygccxml https://bitbucket.org/ompl/pyplusplus/get/1.8.0.tar.gz
    # install castxml
    if [[ $ubuntu_version > 1410 ]]; then
        apt-get -y install castxml
    else
        wget -O - https://midas3.kitware.com/midas/download/item/318227/castxml-linux.tar.gz | tar zxf - -C $HOME
        export PATH=$HOME/castxml/bin:$PATH
    fi
}

install_app_dependencies()
{
    # We prefer PyQt5, but PyQt4 also still works.
    if [[ $ubuntu_version > 1410 ]]; then
        apt-get -y install python${PYTHONV}-pyqt5.qtopengl
    else
        apt-get -y install python-qt4-dev python-qt4-gl
    fi
    apt-get -y install freeglut3-dev libassimp-dev python${PYTHONV}-opengl python${PYTHONV}-flask python${PYTHONV}-celery
    # install additional python dependencies via pip
    pip${PYTHONV} install -vU PyOpenGL-accelerate
    # install libccd
    if [[ $ubuntu_version > 1410 ]]; then
        apt-get -y install libccd-dev
    else
        wget -O - https://github.com/danfis/libccd/archive/v2.0.tar.gz | tar zxf -
        cd libccd-2.0; cmake .; make install; cd ..
    fi
    # install fcl
    if ! pkg-config --atleast-version=0.5.0 fcl; then
        if [[ $ubuntu_version > 1604 ]]; then
            apt-get -y install libfcl-dev
        else
            wget -O - https://github.com/flexible-collision-library/fcl/archive/0.5.0.tar.gz | tar zxf -
            cd fcl-0.5.0; cmake .; make install; cd ..
        fi
    fi
}

install_ompl()
{
    if [ -z $2 ]; then
        OMPL="ompl"
    else
        OMPL="omplapp"
    fi
    wget -O - https://bitbucket.org/ompl/ompl/downloads/$OMPL-1.3.2-Source.tar.gz | tar zxf -
    cd $OMPL-1.3.2-Source
    mkdir -p build/Release
    cd build/Release
    cmake ../..
    if [ ! -z $1 ]; then
        make update_bindings
    fi
    make
    make install
}

for i in "$@"
do
case $i in
    -a|--app)
        APP=1
        PYTHON=1
        shift
        ;;
    -p|--python)
        PYTHON=1
        shift
        ;;
    *)
        # unknown option -> show help
        echo "Usage: `basename $0` [-p] [-a]"
        echo "  -p: enable Python bindings"
        echo "  -a: enable OMPL.app (implies '-p')"
    ;;
esac
done


if [[ ! -z $PYTHON ]]; then
    if [[ $ubuntu_version < 1510 && `uname -m` == "i386" ]]; then
        echo "There is no pre-built binary of CastXML available for 32-bit Ubuntu 15.04 or older"
        echo "To generate the Python bindings, you first need to compile CastXML from source."
        echo "Alternatively, you could change your OS to either a newer version of Ubuntu or 64-bit Ubuntu."
        exit 1
    fi
    # the default version of Python in 17.10 and above is version 3
    if [[ $ubuntu_version > 1704 ]]; then
        PYTHONV=3
    fi
fi

install_common_dependencies
if [ ! -z $PYTHON ]; then
    install_python_binding_dependencies
fi
if [ ! -z $APP ]; then
    install_app_dependencies
fi
install_ompl $PYTHON $APP
