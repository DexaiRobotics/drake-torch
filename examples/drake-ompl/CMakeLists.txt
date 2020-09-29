cmake_minimum_required(VERSION 3.14)
project(drake_ompl)

set(CMAKE_C_COMPILER "gcc-7")
set(CMAKE_CXX_COMPILER "g++-7")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# WARNINGS: Set -Wall and -Wextra, but silence some noisy ones such as -Wshadow
# YMMV: comment or modify these depending on your application
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wsign-compare -Wuninitialized -Wunused-const-variable")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-function -Wno-unused-parameter")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated-declarations -Wno-register")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=1")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")  # optimisation
message("CMAKE_CXX_FLAGS: " ${CMAKE_CXX_FLAGS})
message("CMAKE_CXX_COMPILER: " ${CMAKE_CXX_COMPILER})

# Set Drake's path so we can find it
set(DRAKE_BUILD_DIR "/opt/drake")
list(APPEND CMAKE_PREFIX_PATH ${DRAKE_BUILD_DIR})
list(APPEND CMAKE_PREFIX_PATH "${DRAKE_BUILD_DIR}/lib/cmake")
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/modules")

# import drake
find_package(drake CONFIG REQUIRED)
find_package(GFlags MODULE REQUIRED COMPONENTS shared)

# import ompl (assumed to be installed at /usr/local/include/ompl)
find_package(ompl REQUIRED)
message(STATUS "OMPL_FOUND: ${OMPL_FOUND}")
message(STATUS "OMPL_INCLUDE_DIRS: ${OMPL_INCLUDE_DIRS}")
message(STATUS "OMPL_LIBRARIES: ${OMPL_LIBRARIES}")
message(STATUS "OMPLAPP_LIBRARIES: ${OMPLAPP_LIBRARIES}")
message(STATUS "OMPL_VERSION: ${OMPL_VERSION}")

find_package(Boost REQUIRED COMPONENTS serialization)
message(STATUS "BOOST_LIBRARIES: ${Boost_LIBRARIES}")

set(SPDLOG_INCLUDE_DIR /opt/drake/include/spdlog)
message(STATUS "SPDLOG_INCLUDE_DIR variable defaulted in CMakeList: " ${SPDLOG_INCLUDE_DIR})

# copy test data into the build directory
configure_file(models/box.sdf "${CMAKE_CURRENT_BINARY_DIR}" COPYONLY)

include_directories(
	${OMPL_INCLUDE_DIRS}
	${SPDLOG_INCLUDE_DIR}
)

add_executable(drake_ompl_demo src/drake_ompl_demo.cc)
target_link_libraries(drake_ompl_demo
	drake::drake
	${OMPL_LIBRARIES}
	gflags
)
