cmake_minimum_required(VERSION 3.12)
project(sg)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(PYBIND11_CPP_STANDARD -std=c++14)

set(CMAKE_CXX_FLAGS "-D_GLIBCXX_USE_CXX11_ABI=1")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14 -pthread ")	# -Wshadow (too noisy)
if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wno-deprecated-register -Wno-unused-function")
endif()
message("CMAKE_CXX_FLAGS: " ${CMAKE_CXX_FLAGS})


list(APPEND CMAKE_PREFIX_PATH $ENV{DRAKE_BUILD_DIR})
list(APPEND CMAKE_PREFIX_PATH $ENV{DRAKE_BUILD_DIR}/lib/cmake)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/modules")

IF(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
	find_package(Eigen3 3.3.5 QUIET CONFIG)
ENDIF()

# find_package(Boost 1.58 COMPONENTS serialization filesystem system program_options REQUIRED)
# include_directories(SYSTEM ${Boost_INCLUDE_DIR})

find_package(GTest REQUIRED)
find_package(drake CONFIG REQUIRED)
find_package(gflags MODULE REQUIRED COMPONENTS shared)
find_package(Protobuf REQUIRED)
# find_package(Protobuf 2.6.1 EXACT REQUIRED)
# find_package(Protobuf 3.6.0 EXACT REQUIRED)


## load in pkg-config support
find_package(PkgConfig)
## use pkg-config to get hints for 0mq locations

# find_package(Boost 1.65.1 REQUIRED COMPONENTS date_time regex program_options filesystem system thread)

set(Python2_ROOT_DIR $ENV{LOCAL_PYTHON_PATH})
find_package( Python2 2.7.12 REQUIRED Interpreter Development)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
	set(PYTHON_LIBRARIES ${Python2_LIBRARIES} )
else()
	set(PYTHON_LIBRARIES "/usr/lib/x86_64-linux-gnu/libpython2.7.so") #$ENV{LOCAL_PYTHON_PATH}/lib/libpython2.7.so )
endif()

set(PYTHON_INCLUDE_DIRS "${Python2_INCLUDE_DIRS}"	# kitchen sink
	"/usr/include/python2.7"
	"/usr/local/lib/python2.7/dist-packages/numpy/core/include"
	"${Python2_LIBRARY_DIRS}/python2.7/dist-packages/numpy/core/include"
	"${Python2_LIBRARY_DIRS}/python2.7/site-packages/numpy/core/include")
message("Python2_LIBRARIES: " ${Python2_LIBRARIES})

#### PYTHON ENVIRONMENTS END ####

#### Import Torch ####
# list(APPEND CMAKE_PREFIX_PATH $ENV{TORCH_LIB_DIR})
# find_package(Torch REQUIRED)



if (NOT ${PROTOBUF_LIBRARY})
	set(PROTOBUF_LIBRARY protobuf)
endif()



include_directories(
	include
	utils/visdom
	${PYTHON_INCLUDE_DIRS}
	$ENV{TORCH_INCLUDE_DIR}
)

  add_library(rl_drake SHARED
	utils/visdom/visdom.cc
	examples/drake_cartpole_env.cc
  )

  target_link_libraries(rl_drake
	drake::drake
	gflags
	$ENV{TORCH_LIBRARIES}
	${PYTHON_LIBRARIES}
  )

  add_executable(rl_cartpole examples/rl_cartpole.cc)
  target_link_libraries(rl_cartpole
	drake::drake
	gflags
	$ENV{TORCH_LIBRARIES}
	rl_drake
  )