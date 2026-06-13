cmake_minimum_required(VERSION 3.16)
project(mac_fan_control VERSION 1.1.0 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Compiler warnings
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic -Werror")
endif()

# macOS frameworks
find_library(IOKIT IOKit)
find_library(COREFOUNDATION CoreFoundation)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# Library target
add_library(fan_control STATIC
    src/smc_backend.cpp
    src/intel_smc_backend.cpp
    src/fan_controller.cpp
    src/smc_types.cpp
    src/daemon_ipc.cpp
)

target_link_libraries(fan_control PUBLIC ${IOKIT} ${COREFOUNDATION})

# CLI executable
add_executable(fanctl
    src/main.cpp
    src/daemon_client.cpp
)
target_link_libraries(fanctl PRIVATE fan_control)

# Daemon executable
add_executable(fanctld
    src/fanctld.cpp
    src/daemon_ipc.cpp
)
target_link_libraries(fanctld PRIVATE fan_control)

if(BUILD_TESTING)
    add_executable(unit_tests
        tests/unit_tests.cpp
    )
    target_link_libraries(unit_tests PRIVATE fan_control)
    add_test(NAME unit_tests COMMAND unit_tests)
endif()

# Install targets
install(TARGETS fan_control fanctl fanctld
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
install(DIRECTORY include/ DESTINATION include)
