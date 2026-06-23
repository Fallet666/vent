cmake_minimum_required(VERSION 3.16)
project(vent VERSION 1.2.6 LANGUAGES CXX)

include(CTest)

set(CMAKE_OSX_DEPLOYMENT_TARGET 12.0)
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
add_library(vent STATIC
    src/smc_backend.cpp
    src/intel_smc_backend.cpp
    src/fan_controller.cpp
    src/smc_types.cpp
    src/daemon_ipc.cpp
)

target_link_libraries(vent PUBLIC ${IOKIT} ${COREFOUNDATION})

# CLI executable
add_executable(ventctl
    src/main.cpp
    src/daemon_client.cpp
)
target_link_libraries(ventctl PRIVATE vent)

# Daemon executable
add_executable(ventd
    src/ventd.cpp
    src/daemon_ipc.cpp
)
target_link_libraries(ventd PRIVATE vent)

if(BUILD_TESTING)
    add_executable(unit_tests
        tests/unit_tests.cpp
    )
    target_link_libraries(unit_tests PRIVATE vent)
    add_test(NAME unit_tests COMMAND unit_tests)
endif()

# Install targets
install(TARGETS vent ventctl ventd
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
install(DIRECTORY include/ DESTINATION include)
