# HyperMind

A distributed neural network framework built on actor-based concurrency and reactive streams for high-performance, scalable deep learning computation.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-comprehensive-brightgreen.svg)](docs/)
[![Formal Specs](https://img.shields.io/badge/specs-Z++-purple.svg)](specs/)

## Overview

HyperMind is a sophisticated distributed neural network framework that combines cutting-edge concurrency patterns with formal verification to deliver a robust, scalable platform for deep learning workloads. Built on the actor model with reactive stream processing, HyperMind enables network-transparent computation across distributed GPU and CPU resources.

### Key Features

- **🎭 Actor-Based Concurrency**: Thread-safe, message-passing architecture with isolated state
- **⚡ Reactive Streams**: Event-driven processing from multiple sources (CPU, GPU, Database)
- **🔗 Command Pattern**: Extensible asynchronous operations with proxy-based chaining
- **🌐 Distributed Computing**: Network-transparent neural network computation
- **🔒 Formally Specified**: Complete Z++ formal specifications for correctness verification
- **🚀 GPU Acceleration**: Native CUDA/OpenCL integration via dedicated streams
- **💾 Persistent State**: Asynchronous PostgreSQL integration for model persistence
- **📊 Hierarchical Processing**: Three-tier worker-manager-director computation model

## Architecture

HyperMind's architecture is built on four core components:

### 1. NeuralReactor
The fundamental computational unit that:
- Processes messages from multiple priority queues (internal, external, command)
- Handles asynchronous events from GPU streams and PostgreSQL pipes
- Manages session state and NDArray caches using hash maps
- Executes feedforward and backpropagation operations
- Implements hierarchical ranks (worker, manager, director)

### 2. SessionInitiator
Orchestrates neural network computation sessions:
- Creates and distributes sessions across available reactors
- Manages layer sequences for network topology
- Tracks session lifecycle (active, completed, failed)
- Balances load across reactor pool

### 3. Command System
Implements asynchronous operations:
- `Command` base class with extensible `execute()` method
- `FeedForward` and `BackPropagation` commands
- `CommandProxy` for operation chaining
- Priority-based command queuing

### 4. Integration Layer
Provides contracts for external systems:
- **GPU Integration**: CUDA/OpenCL operations via dedicated streams
- **PostgreSQL Integration**: Asynchronous persistence via database pipes
- **Network Integration**: Distributed reactor communication

For detailed architecture documentation, see [docs/architecture_overview.md](docs/architecture_overview.md).

## Documentation

HyperMind includes comprehensive documentation and formal specifications:

### Documentation Files
- **[docs/README.md](docs/README.md)** - Documentation index and navigation guide
- **[docs/architecture_overview.md](docs/architecture_overview.md)** - Detailed architecture with 10 Mermaid diagrams
- **[docs/implementation_guide.md](docs/implementation_guide.md)** - Step-by-step implementation instructions
- **[docs/test_generation_guide.md](docs/test_generation_guide.md)** - Test generation from formal specs

### Formal Specifications (Z++)
- **[specs/data_model.zpp](specs/data_model.zpp)** - Core data structures (NDArray, SessionState, Commands)
- **[specs/system_state.zpp](specs/system_state.zpp)** - System state and global invariants
- **[specs/operations.zpp](specs/operations.zpp)** - Operation specifications with pre/postconditions
- **[specs/integrations.zpp](specs/integrations.zpp)** - External system contracts (GPU, DB, Network)

See [SPECIFICATION_SUMMARY.md](SPECIFICATION_SUMMARY.md) for a complete overview of all specifications.

## Quick Start

### Prerequisites

- C++17 or later
- CMake 3.15+
- CUDA Toolkit 11.0+ (for GPU support)
- PostgreSQL 12+ (for persistence)
- Google Test (for testing)

### Building

```bash
# Clone the repository
git clone https://github.com/o9nn/hypermind.git
cd hypermind

# Create build directory
mkdir build && cd build

# Configure with CMake
cmake ..

# Build
make -j$(nproc)
```

### Running Tests

```bash
# Run all tests
./hypermind_tests

# Run specific test suite
./hypermind_tests --gtest_filter=NDArrayTest.*

# Run with verbose output
./hypermind_tests --gtest_verbose
```

### Basic Usage

```cpp
#include "hypermind.hpp"

// Create a session initiator with 4 reactors
SessionInitiator initiator(4);

// Define neural network layers
std::vector<LayerProxy> layers = {
    LayerProxy(784, 128),  // Input layer
    LayerProxy(128, 64),   // Hidden layer
    LayerProxy(64, 10)     // Output layer
};

// Create a computation session
ID session_id = initiator.createSession(layers);

// Submit input data
NDArray input({784}, Device::CPU, DataType::float32);
initiator.feedForward(session_id, input);

// Retrieve results
NDArray output = initiator.getResult(session_id);
```

## Current Status

HyperMind is currently in **active development**. The project includes:

✅ **Complete Formal Specifications** - All core components formally specified in Z++  
✅ **Comprehensive Documentation** - Architecture diagrams, implementation guides, test generation guides  
✅ **Core Data Structures** - Basic implementation in `hypermind.hpp`  
🚧 **Implementation In Progress** - See [docs/implementation_guide.md](docs/implementation_guide.md) for next steps  

### Next Implementation Steps

From the implementation guide, the following components are planned:

- [ ] Remaining operations (BackPropagation, weight updates, gradient computation)
- [ ] Comprehensive error handling and recovery
- [ ] Full GPU integration (CUDA/OpenCL backends)
- [ ] Complete database integration (PostgreSQL async operations)
- [ ] Performance monitoring and profiling
- [ ] Integration tests for distributed scenarios
- [ ] Network communication layer

See the [implementation guide](docs/implementation_guide.md#next-steps) for details.

## Technical Approach

### Concurrency Model
- Each NeuralReactor runs in its own thread (ThreadActor)
- Lock-free communication via priority queues
- No shared mutable state between actors
- Message passing ensures thread safety

### Queue Architecture
Each NeuralReactor maintains four event sources:
1. **Internal Priority Queue** - Self-scheduled operations (highest priority)
2. **External Priority Queue** - Messages from other reactors
3. **GPU Event Stream** - Asynchronous GPU computation results
4. **PostgreSQL Pipe** - Database operation results

### Hierarchical Processing
Three-tier distributed computation model:
- **Workers** - Execute basic layer computations
- **Managers** - Coordinate workers for complex operations
- **Directors** - Orchestrate managers for full network passes

## Scalability

HyperMind is designed for horizontal and vertical scaling:

- **Horizontal Scaling**: Add reactor instances across machines
- **Vertical Scaling**: GPU acceleration and async database operations
- **Network Transparency**: Reactors communicate regardless of location
- **Load Balancing**: Automatic work distribution across reactor pool

## Formal Verification

HyperMind's formal Z++ specifications enable:

- **Type Checking** - Verify data structure consistency
- **Invariant Checking** - Prove operations maintain invariants
- **Test Generation** - Derive test cases from specifications
- **Model Checking** - Verify distributed system properties
- **Refinement** - Gradually refine specs to implementation

See [docs/test_generation_guide.md](docs/test_generation_guide.md) for test generation from specs.

## Contributing

We welcome contributions! To contribute:

1. Read the [architecture documentation](docs/architecture_overview.md)
2. Review the [formal specifications](specs/)
3. Follow the [implementation guide](docs/implementation_guide.md)
4. Generate tests using the [test generation guide](docs/test_generation_guide.md)
5. Submit a pull request

### Development Guidelines

- All implementations must match formal specifications in `specs/`
- Maintain invariants specified in Z++ schemas
- Add tests for new operations
- Document architectural changes with Mermaid diagrams
- Ensure thread safety in actor implementations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: [docs/](docs/)
- **Specifications**: [specs/](specs/)
- **Issues**: [GitHub Issues](https://github.com/o9nn/hypermind/issues)
- **Agent**: See [.github/agents/hypermind.md](.github/agents/hypermind.md) for GitHub Copilot agent configuration

## Acknowledgments

HyperMind combines ideas from:
- Actor Model (Hewitt, 1973)
- Reactive Streams (Reactive Manifesto)
- Command Pattern (Gang of Four)
- Formal Methods (Z Notation, Z++)
- Distributed Computing (MapReduce, Actor Frameworks)

---

**Built with ❤️ for high-performance distributed deep learning**
