cmake_minimum_required(VERSION 3.8)
project(sa)

include_directories(./src)
file(GLOB SOURCES "./src/*.cpp")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O2")

# Disable fast math optimizations for more deterministic FP behavior
# set(
#   CMAKE_CXX_FLAGS
#   "${CMAKE_CXX_FLAGS} -g -O2 -ffp-contract=off -frounding-math "
#   "-fno-fast-math"
# )
# set(
#   CMAKE_EXE_LINKER_FLAGS
#   "${CMAKE_EXE_LINKER_FLAGS} -rdynamic"
# )  # Enable symbols for stack trace

# Static link libgcc and libstdc++ for more reproducibility
# set(
#   CMAKE_EXE_LINKER_FLAGS
#   "${CMAKE_EXE_LINKER_FLAGS} -rdynamic -static-libgcc -static-libstdc++"
# )

add_executable(${PROJECT_NAME} ${SOURCES})
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

find_package(OpenMP REQUIRED)
if(OpenMP_CXX_FOUND)
  target_link_libraries(${PROJECT_NAME} PRIVATE OpenMP::OpenMP_CXX)
endif()