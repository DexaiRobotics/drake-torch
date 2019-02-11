#!/bin/bash
# build & run the uniformly accelerated particle example
clean_build=${1:-1} # Remove the build directory and start over if > 0.  Defaults to Yes (1).

cd particles
if (( $clean_build > 0 )); then
    #if the CMakeCache.txt file exists, remove it.
    if [ -f CMakeCache.txt ]; then
      rm -f CMakeCache.txt
    fi
    #if the build directory exists, remove it.
    if [ -d build ]; then
      rm -rf build
    fi
fi

# Now build the target from scratch:
mkdir -p build; cd build

cmake -DCMAKE_PREFIX_PATH="/opt/libtorch;/opt/drake" -DCMAKE_MODULE_PATH="/src/cmake/modules" -DCMAKE_BUILD_TYPE=Release ..
make
./uniformly_accelerated_particle
