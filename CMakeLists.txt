cmake_minimum_required(VERSION 3.15)
project(HyperMind VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -O2")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -O0")

# Find packages
find_package(Threads REQUIRED)

# Optional: Find CUDA if available
find_package(CUDA QUIET)
if(CUDA_FOUND)
    message(STATUS "CUDA found: ${CUDA_VERSION}")
    add_definitions(-DHYPERMIND_CUDA_ENABLED)
    include_directories(${CUDA_INCLUDE_DIRS})
else()
    message(STATUS "CUDA not found - GPU support disabled")
endif()

# Optional: Find PostgreSQL if available
find_package(PostgreSQL QUIET)
if(PostgreSQL_FOUND)
    message(STATUS "PostgreSQL found: ${PostgreSQL_VERSION}")
    add_definitions(-DHYPERMIND_POSTGRESQL_ENABLED)
    include_directories(${PostgreSQL_INCLUDE_DIRS})
else()
    message(STATUS "PostgreSQL not found - Database support disabled")
endif()

# Include directories
include_directories(${CMAKE_SOURCE_DIR})

# Library target (header-only for now)
add_library(hypermind INTERFACE)
target_include_directories(hypermind INTERFACE ${CMAKE_SOURCE_DIR})

# Optional: Enable Google Test for unit tests
option(BUILD_TESTS "Build tests" ON)
if(BUILD_TESTS)
    # Try to find Google Test
    find_package(GTest QUIET)
    
    if(GTest_FOUND)
        enable_testing()
        
        # Test executables
        add_executable(session_lifecycle_test tests/session_lifecycle_test.cpp)
        target_link_libraries(session_lifecycle_test 
            hypermind 
            GTest::GTest 
            GTest::Main
            Threads::Threads
        )
        add_test(NAME SessionLifecycle COMMAND session_lifecycle_test)
        
        add_executable(multi_reactor_test tests/multi_reactor_test.cpp)
        target_link_libraries(multi_reactor_test 
            hypermind 
            GTest::GTest 
            GTest::Main
            Threads::Threads
        )
        add_test(NAME MultiReactor COMMAND multi_reactor_test)
        
        add_executable(performance_test tests/performance_test.cpp)
        target_link_libraries(performance_test 
            hypermind 
            GTest::GTest 
            GTest::Main
            Threads::Threads
        )
        add_test(NAME Performance COMMAND performance_test)
        
        message(STATUS "Tests enabled")
    else()
        message(STATUS "Google Test not found - tests disabled")
        message(STATUS "To enable tests, install Google Test:")
        message(STATUS "  Ubuntu/Debian: sudo apt-get install libgtest-dev")
        message(STATUS "  macOS: brew install googletest")
    endif()
endif()

# Optional: Link CUDA libraries if available
if(CUDA_FOUND)
    target_link_libraries(hypermind INTERFACE ${CUDA_LIBRARIES})
endif()

# Optional: Link PostgreSQL libraries if available
if(PostgreSQL_FOUND)
    target_link_libraries(hypermind INTERFACE ${PostgreSQL_LIBRARIES})
endif()

# Installation rules
install(FILES hypermind.hpp DESTINATION include)
install(DIRECTORY specs/ DESTINATION share/hypermind/specs)
install(DIRECTORY docs/ DESTINATION share/hypermind/docs)

# Print configuration summary
message(STATUS "")
message(STATUS "HyperMind Configuration:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  CUDA Support: ${CUDA_FOUND}")
message(STATUS "  PostgreSQL Support: ${PostgreSQL_FOUND}")
message(STATUS "  Tests: ${BUILD_TESTS}")
message(STATUS "")
