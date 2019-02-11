#!/bin/bash


# Positional Parameters for specifying different behavior via the command line.
# see http://linuxcommand.org/lc3_wss0120.php
# Example CircleCI usage (from .circleci/config.yml): ./setup.sh 4 1 1
num_threads=${1:-9} # Num threads for make -j.  For CircleCI, try using 4.
build_tests=${2:-1} # Build the tests?  Yes if build_tests > 0 or exec_ctests > 0.
build_local=${3:-1} # Define BUILD_LOCAL_TESTS as a compiler flag (CXX_FLAGS) if > 0.  Defaults to Yes (1).
exec_ctests=${4:-1} # Run ctest if all else succeeds?   Defaults to Yes (1 > 0).
build_otype=${5:-0} # Set build type: 0=Default, 1=Debug (with symbols), 2=Release (-O3)
clean_build=${6:-1} # Remove the build directory and start over if > 0.  Defaults to Yes (1).
skip_slower=${7:-0} # Skip the slow tests, such as test_foi (or all matching 'test_[A-Z].+').  Defaults to No (0).
exclude_pat=${8:-test_foi} # Regex for excluding some (slow) tests, such as test_foi.
run_pytests=${9:-1} # Run Python unit tests even if nothing else?   Defaults to Yes (1 > 0).

if (( $build_tests > 0 )); then
    target=all
else
    target=ice_cream_scooper    # build only the main library
fi
echo "####### make will use $num_threads jobs to build target: $target #######"

source scripts/setup_env.sh

if (( $exec_ctests > 2 )); then
    echo "Trying to run python and c++ unit tests before re-building... (risky)"
    cd tests && nose2                 || exit 2  # run unit tests or die
    cd ../build && ctest && cd ..     || exit 3  # run unit tests or die
fi

if (( $build_local > 0 )); then
    # Temporary message until everyone groks the changed options.
    echo "========================= BUILD_LOCAL_TESTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    CXX_FLAGS="-DBUILD_LOCAL_TESTS=2"
else
    CXX_FLAGS=" "
fi



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

if (( $build_otype == 1 )); then
    echo "#=#=#=#=#=#=#=#=#=#=#=#=# CALLING cmake .. -DCMAKE_BUILD_TYPE=Debug #=#=#=#=#=#=#=#=#=#=#=#"
    cmake .. -DCMAKE_BUILD_TYPE=Debug   || exit 4   # Build for debugging
elif (( $build_otype > 1 )); then
    echo ">=>=>=>=>=>=>=>=>=>=>=>=> CALLING cmake .. -DCMAKE_BUILD_TYPE=Release (-O3) >=>=>=>=>=>=>=>"
    cmake .. -DCMAKE_BUILD_TYPE=Release || exit 5   # Build for release (or profiling)
else
    cmake ..                            || exit 6
fi

make  -j $num_threads $target           || exit 6

# ctest / gtest
if (( $exec_ctests > 0 )); then
    if (( $skip_slower )); then
        ctest -E $exclude_pat           || exit 7   # exclude tests matching the regex
    else
        ctest                           || exit 8   # run all unit tests
    fi
fi

# python tests/nose2; depend on ctest products:
if (( $run_pytests > 0 && $exec_ctests > 0 )); then
    cd ../tests
    echo "Running all Python unit tests under $PWD as the last step..."
    nose2 -v
    status=$?
    if (( $status != 0 )); then
        echo "nose2 exit status: $status (FAILED)"
        echo "Hello, $USER.  You busted your nose?  If nose2 is not installed, try 'pip install nose2'"
        echo "NOTE: The Python unit tests use files made by the C++ ctest/gtest suite, so run it first."
        exit $status
    else
        echo "nose2 exit status: $status (PASSED)"
    fi
    cd ..
fi
