# HyperMind Makefile
# Simple build system for development

CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O2 -I.
LDFLAGS = -pthread

# Optional: Add CUDA flags if nvcc is available
NVCC = nvcc
CUDA_FLAGS = -std=c++17 -O2

# Optional: Add PostgreSQL flags if pg_config is available
PG_CFLAGS = $(shell pg_config --includedir 2>/dev/null | sed 's/^/-I/')
PG_LDFLAGS = $(shell pg_config --libdir 2>/dev/null | sed 's/^/-L/') -lpq

# Test framework
GTEST_LIBS = -lgtest -lgtest_main

# Detect available features
HAS_GTEST := $(shell echo '\#include <gtest/gtest.h>' | $(CXX) -E - >/dev/null 2>&1 && echo 1 || echo 0)
HAS_CUDA := $(shell command -v $(NVCC) >/dev/null 2>&1 && echo 1 || echo 0)
HAS_PG := $(shell command -v pg_config >/dev/null 2>&1 && echo 1 || echo 0)

# Adjust flags based on available features
ifeq ($(HAS_CUDA),1)
    CXXFLAGS += -DHYPERMIND_CUDA_ENABLED
endif

ifeq ($(HAS_PG),1)
    CXXFLAGS += -DHYPERMIND_POSTGRESQL_ENABLED $(PG_CFLAGS)
    LDFLAGS += $(PG_LDFLAGS)
endif

# Targets
.PHONY: all clean test info help

all: info
	@echo "HyperMind is a header-only library."
	@echo "Include hypermind.hpp in your project."
	@echo "Run 'make test' to build and run tests."

info:
	@echo "=== HyperMind Build Configuration ==="
	@echo "C++ Compiler: $(CXX)"
	@echo "C++ Standard: C++17"
	@echo "CUDA Support: $(HAS_CUDA)"
	@echo "PostgreSQL Support: $(HAS_PG)"
	@echo "Google Test Available: $(HAS_GTEST)"
	@echo ""

test: test-build test-run

test-build:
ifeq ($(HAS_GTEST),1)
	@echo "Building tests..."
	@mkdir -p build
	$(CXX) $(CXXFLAGS) tests/session_lifecycle_test.cpp -o build/session_lifecycle_test $(LDFLAGS) $(GTEST_LIBS)
	$(CXX) $(CXXFLAGS) tests/multi_reactor_test.cpp -o build/multi_reactor_test $(LDFLAGS) $(GTEST_LIBS)
	$(CXX) $(CXXFLAGS) tests/performance_test.cpp -o build/performance_test $(LDFLAGS) $(GTEST_LIBS)
	@echo "Tests built successfully."
else
	@echo "Google Test not found. Please install:"
	@echo "  Ubuntu/Debian: sudo apt-get install libgtest-dev"
	@echo "  macOS: brew install googletest"
	@exit 1
endif

test-run:
ifeq ($(HAS_GTEST),1)
	@echo ""
	@echo "Running tests..."
	@echo "--- Session Lifecycle Tests ---"
	-./build/session_lifecycle_test
	@echo ""
	@echo "--- Multi-Reactor Tests ---"
	-./build/multi_reactor_test
	@echo ""
	@echo "--- Performance Tests ---"
	-./build/performance_test
else
	@echo "Tests not built. Run 'make test-build' first."
endif

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -f *.o
	@echo "Clean complete."

help:
	@echo "HyperMind Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Show information (default)"
	@echo "  info       - Display build configuration"
	@echo "  test       - Build and run all tests"
	@echo "  test-build - Build test executables"
	@echo "  test-run   - Run test executables"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "HyperMind is primarily a header-only library."
	@echo "Include hypermind.hpp in your C++ projects."
