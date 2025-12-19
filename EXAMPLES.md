# HyperMind Usage Examples

This document provides practical examples of using the HyperMind distributed neural network framework.

## Table of Contents

- [Basic Neural Network Setup](#basic-neural-network-setup)
- [Creating and Running Sessions](#creating-and-running-sessions)
- [Multi-Reactor Configuration](#multi-reactor-configuration)
- [Error Handling](#error-handling)
- [Performance Monitoring](#performance-monitoring)
- [GPU Acceleration](#gpu-acceleration)
- [Database Persistence](#database-persistence)
- [Distributed Training](#distributed-training)

## Basic Neural Network Setup

### Simple Feed-Forward Network

```cpp
#include "hypermind.hpp"
#include <iostream>
#include <vector>

int main() {
    // Create a session initiator with 4 reactor workers
    SessionInitiator initiator(4);
    
    // Define network topology: 784 -> 128 -> 64 -> 10
    std::vector<LayerProxy> layers = {
        LayerProxy(784, 128),  // Input layer (MNIST: 28x28 = 784)
        LayerProxy(128, 64),   // Hidden layer 1
        LayerProxy(64, 10)     // Output layer (10 classes)
    };
    
    // Create computation session
    ID session_id = initiator.createSession(layers);
    
    std::cout << "Session created: " << session_id << std::endl;
    
    return 0;
}
```

## Creating and Running Sessions

### Forward Pass Example

```cpp
#include "hypermind.hpp"

void runForwardPass() {
    SessionInitiator initiator(2);
    
    // Define layers
    std::vector<LayerProxy> layers = {
        LayerProxy(784, 256),
        LayerProxy(256, 128),
        LayerProxy(128, 10)
    };
    
    // Create session
    ID session_id = initiator.createSession(layers);
    
    // Prepare input data (flattened 28x28 image)
    NDArray input({784}, Device::CPU, DataType::float32);
    // ... fill input with data ...
    
    // Submit forward pass command
    FeedForward* cmd = new FeedForward();
    cmd->_this_layer = layers[0];
    cmd->_rank = 'w';  // worker rank
    
    // Wait for completion
    SessionState state = initiator.getSessionState(session_id);
    while (state.getState() != COMPLETED) {
        // Poll or wait
        state = initiator.getSessionState(session_id);
    }
    
    // Retrieve output
    NDArray output = initiator.getResult(session_id);
}
```

### Training Loop with Backpropagation

```cpp
#include "hypermind.hpp"

void trainingLoop(int epochs, float learning_rate) {
    SessionInitiator initiator(4);
    
    std::vector<LayerProxy> layers = {
        LayerProxy(784, 256),
        LayerProxy(256, 10)
    };
    
    for (int epoch = 0; epoch < epochs; epoch++) {
        // Forward pass
        ID forward_session = initiator.createSession(layers);
        // ... execute forward pass ...
        
        // Backward pass
        ID backward_session = initiator.createSession(layers);
        BackPropagation* backprop = new BackPropagation();
        // ... configure and execute backprop ...
        
        // Weight update
        WeightUpdate* update = new WeightUpdate();
        update->_learning_rate = learning_rate;
        // ... execute weight update ...
        
        std::cout << "Epoch " << epoch << " complete" << std::endl;
    }
}
```

## Multi-Reactor Configuration

### Hierarchical Processing Setup

```cpp
#include "hypermind.hpp"

void setupHierarchicalProcessing() {
    // Create reactors at different ranks
    NeuralReactor* workers[8];
    NeuralReactor* managers[2];
    NeuralReactor* director;
    
    // Initialize workers
    for (int i = 0; i < 8; i++) {
        workers[i] = new NeuralReactor();
        workers[i]->setRank('w');  // worker rank
    }
    
    // Initialize managers
    for (int i = 0; i < 2; i++) {
        managers[i] = new NeuralReactor();
        managers[i]->setRank('m');  // manager rank
    }
    
    // Initialize director
    director = new NeuralReactor();
    director->setRank('d');  // director rank
    
    // Start all reactors
    for (auto* worker : workers) worker->start();
    for (auto* manager : managers) manager->start();
    director->start();
    
    std::cout << "Hierarchical processing configured" << std::endl;
}
```

## Error Handling

### Robust Command Execution

```cpp
#include "hypermind.hpp"

void robustCommandExecution() {
    NeuralReactor reactor;
    
    try {
        // Create and execute command
        FeedForward* cmd = new FeedForward();
        reactor.handle_command(cmd);
        
    } catch (const std::exception& e) {
        // Error is automatically handled in NeuralReactor
        std::cerr << "Command execution failed: " << e.what() << std::endl;
        
        // Check metrics for error details
        PerformanceMetrics metrics = reactor.get_metrics();
        std::cout << "Failed operations: " << metrics.failed_operations << std::endl;
    }
}
```

### Custom Error Handling

```cpp
void handleIntegrationErrors(const IntegrationError& error) {
    switch (error.severity) {
        case WARNING:
            std::cout << "[WARNING] " << error.message << std::endl;
            // Continue execution
            break;
            
        case ERROR:
            std::cerr << "[ERROR] " << error.message << std::endl;
            // Attempt recovery
            if (error.source == "GPU") {
                // Fallback to CPU
            }
            break;
            
        case CRITICAL:
            std::cerr << "[CRITICAL] " << error.message << std::endl;
            // Shutdown gracefully
            exit(1);
            break;
    }
}
```

## Performance Monitoring

### Collecting and Reporting Metrics

```cpp
#include "hypermind.hpp"
#include <iostream>

void monitorPerformance(NeuralReactor* reactor) {
    // Get current metrics
    PerformanceMetrics metrics = reactor->get_metrics();
    
    std::cout << "=== Performance Metrics ===" << std::endl;
    std::cout << "Total operations: " << metrics.total_operations << std::endl;
    std::cout << "Successful: " << metrics.successful_operations << std::endl;
    std::cout << "Failed: " << metrics.failed_operations << std::endl;
    std::cout << "Success rate: " 
              << (100.0 * metrics.successful_operations / metrics.total_operations) 
              << "%" << std::endl;
    std::cout << "Average latency: " << metrics.average_latency_ms << " ms" << std::endl;
    std::cout << "GPU memory used: " << metrics.gpu_memory_used << " bytes" << std::endl;
    std::cout << "Active sessions: " << metrics.active_sessions << std::endl;
}
```

## GPU Acceleration

### Submitting GPU Operations

```cpp
#include "hypermind.hpp"

void useGPUAcceleration() {
    NeuralReactor reactor;
    
    // Prepare GPU operation
    GPUOperation* op = new GPUOperation();
    op->type = MatrixMultiply;
    op->operation_id = 12345;
    // ... set input/output pointers and sizes ...
    
    // Submit to GPU stream
    reactor.submit_gpu_operation(op);
    
    // GPU completion is handled asynchronously via handle_gpu_event()
}
```

### GPU Event Handling

```cpp
void processGPUResults(Event* event) {
    GPUResult* result = static_cast<GPUResult*>(event->getData());
    
    if (result->success) {
        std::cout << "GPU operation " << result->operation_id 
                  << " completed successfully" << std::endl;
    } else {
        std::cerr << "GPU operation failed: " 
                  << result->error.message << std::endl;
    }
}
```

## Database Persistence

### Saving Model State

```cpp
#include "hypermind.hpp"

void saveModelState(NeuralReactor* reactor, const std::string& model_name) {
    DatabaseQuery* query = new DatabaseQuery();
    query->type = INSERT;
    query->query_id = 1001;
    query->sql = "INSERT INTO models (name, weights, timestamp) VALUES ($1, $2, NOW())";
    query->parameters = {model_name, /* serialized weights */};
    
    reactor->submit_database_query(query);
}
```

### Loading Model State

```cpp
void loadModelState(NeuralReactor* reactor, const std::string& model_name) {
    DatabaseQuery* query = new DatabaseQuery();
    query->type = SELECT_QUERY;
    query->query_id = 1002;
    query->sql = "SELECT weights FROM models WHERE name = $1 ORDER BY timestamp DESC LIMIT 1";
    query->parameters = {model_name};
    
    reactor->submit_database_query(query);
    
    // Result handled asynchronously via handle_database_event()
}
```

## Distributed Training

### Network Communication Setup

```cpp
#include "hypermind.hpp"

void setupDistributedTraining() {
    // Node 1: Create local reactors
    NetworkInterface* network1 = new NetworkInterface("192.168.1.10");
    NeuralReactor* local_reactor1 = new NeuralReactor();
    
    // Node 2: Create remote reactor reference
    network1->register_reactor("192.168.1.11", 2);
    
    // Send message to remote reactor
    Message* msg = new Message();
    msg->setSender(1);
    msg->setReceiver(2);
    
    network1->send_network_message(msg, "192.168.1.11");
    
    std::cout << "Distributed training network configured" << std::endl;
}
```

### Cross-Node Gradient Aggregation

```cpp
void aggregateDistributedGradients() {
    NetworkInterface network("192.168.1.10");
    
    // Each node computes local gradients
    NDArray local_gradient = computeLocalGradient();
    
    // Send to aggregator node
    Message* gradient_msg = new Message();
    // ... serialize gradient into message ...
    
    network.send_network_message(gradient_msg, "192.168.1.100");
    
    // Aggregator averages gradients and broadcasts back
    // Each node applies the averaged gradient
}
```

## Complete Training Example

```cpp
#include "hypermind.hpp"
#include <iostream>

int main() {
    // Initialize framework
    SessionInitiator initiator(4);
    
    // Define network
    std::vector<LayerProxy> layers = {
        LayerProxy(784, 256),
        LayerProxy(256, 128),
        LayerProxy(128, 10)
    };
    
    // Training parameters
    const int epochs = 10;
    const float learning_rate = 0.01;
    const int batch_size = 32;
    
    // Training loop
    for (int epoch = 0; epoch < epochs; epoch++) {
        std::cout << "Epoch " << epoch + 1 << "/" << epochs << std::endl;
        
        // Process batches
        for (int batch = 0; batch < num_batches; batch++) {
            // Create session
            ID session = initiator.createSession(layers);
            
            // Forward pass
            FeedForward* forward = new FeedForward();
            // ... configure and execute ...
            
            // Backward pass
            BackPropagation* backward = new BackPropagation();
            backward->_learning_rate = learning_rate;
            // ... configure and execute ...
            
            // Weight update
            WeightUpdate* update = new WeightUpdate();
            update->_learning_rate = learning_rate;
            // ... configure and execute ...
        }
        
        std::cout << "Epoch complete" << std::endl;
    }
    
    std::cout << "Training complete!" << std::endl;
    return 0;
}
```

## Further Reading

- [Architecture Overview](docs/architecture_overview.md) - Detailed system architecture
- [Implementation Guide](docs/implementation_guide.md) - Step-by-step implementation
- [Formal Specifications](specs/) - Z++ formal specifications
- [Test Generation Guide](docs/test_generation_guide.md) - Testing approaches
