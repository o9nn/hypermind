# HyperMind Implementation Guide

## Introduction

This guide provides step-by-step instructions for implementing components of the HyperMind distributed neural network framework based on the formal Z++ specifications in the `specs/` directory.

## Prerequisites

Before implementing HyperMind components, ensure you understand:
- The actor model and message-passing concurrency
- C++ templates and polymorphism
- Multi-threading and synchronization primitives
- Basic neural network concepts (layers, activations, forward/backward passes)
- The formal specifications in `specs/data_model.zpp`, `specs/system_state.zpp`, `specs/operations.zpp`, and `specs/integrations.zpp`

## Implementation Approach

### General Strategy

1. **Start with Data Structures** (`specs/data_model.zpp`)
   - Implement basic types and schemas
   - Add invariant checks in constructors/methods
   - Use assertions to verify invariants during development

2. **Build Actor State** (`specs/system_state.zpp`)
   - Implement queue management
   - Create state containers matching formal specs
   - Initialize with valid states per invariants

3. **Implement Operations** (`specs/operations.zpp`)
   - Follow precondition → action → postcondition pattern
   - Verify invariant preservation
   - Add error handling for precondition violations

4. **Add Integrations** (`specs/integrations.zpp`)
   - Implement external system contracts
   - Add retry logic and error handling
   - Implement rate limiting and backpressure

## Part 1: Implementing Core Data Structures

### 1.1 NDArray Implementation

Based on `data_model.zpp`, the NDArray schema specifies:

```z++
schema NDArray
  shape: seq ℕ
  data: seq ℝ
  device: Device
  dtype: DataType
where
  #shape > 0 ∧ (∀ i : 1..#shape @ shape(i) > 0)
  #data = ∏{i : 1..#shape @ shape(i)}
  (∀ i : 1..#data @ ¬isInfinite(data(i)) ∧ ¬isNaN(data(i)))
end
```

**C++ Implementation:**

```cpp
#include <vector>
#include <numeric>
#include <stdexcept>
#include <cmath>

enum class Device { CPU, GPU, Distributed };
enum class DataType { float16, float32, float64, int8, int16, int32, int64 };

class NDArray {
private:
    std::vector<size_t> shape_;
    std::vector<double> data_;
    Device device_;
    DataType dtype_;
    
    // Helper to compute product of shape dimensions
    size_t compute_size() const {
        return std::accumulate(shape_.begin(), shape_.end(), 
                             size_t(1), std::multiplies<size_t>());
    }
    
    // Invariant checker
    void check_invariants() const {
        // Invariant: shape must be non-empty with all positive dimensions
        if (shape_.empty()) {
            throw std::invalid_argument("NDArray shape cannot be empty");
        }
        for (size_t dim : shape_) {
            if (dim == 0) {
                throw std::invalid_argument("All shape dimensions must be positive");
            }
        }
        
        // Invariant: data size must match product of shape
        if (data_.size() != compute_size()) {
            throw std::invalid_argument("Data size must match product of shape dimensions");
        }
        
        // Invariant: data must contain finite values
        for (double val : data_) {
            if (std::isnan(val) || std::isinf(val)) {
                throw std::invalid_argument("NDArray data must not contain NaN or Inf");
            }
        }
    }

public:
    // Constructor - establishes invariants
    NDArray(std::vector<size_t> shape, Device device, DataType dtype)
        : shape_(std::move(shape)), device_(device), dtype_(dtype) {
        size_t size = compute_size();
        data_.resize(size, 0.0);
        check_invariants();
    }
    
    // Accessors preserving invariants
    const std::vector<size_t>& shape() const { return shape_; }
    const std::vector<double>& data() const { return data_; }
    Device device() const { return device_; }
    DataType dtype() const { return dtype_; }
    
    // Mutator with invariant checking
    void set_data(std::vector<double> new_data) {
        if (new_data.size() != compute_size()) {
            throw std::invalid_argument("New data size must match array shape");
        }
        data_ = std::move(new_data);
        check_invariants();
    }
};
```

**Key Points:**
- Constructor establishes all invariants from the formal specification
- `check_invariants()` method verifies formal constraints
- All mutators preserve invariants
- Use exceptions for precondition violations

### 1.2 SessionState Implementation

Based on `data_model.zpp`:

```cpp
#include <set>
#include <cstdint>

// State codes from formal spec
enum StateCode {
    INIT = 0,
    PROCESSING = 1,
    WAITING_GPU = 2,
    WAITING_DB = 3,
    COMPLETED = 4,
    FAILED = 5
};

class SessionState {
private:
    uint64_t session_id_;
    StateCode state_;
    size_t layer_index_;
    std::set<size_t> completed_layers_;
    size_t pending_operations_;
    
    void check_invariants() const {
        // Invariant: state code is valid
        if (state_ < INIT || state_ > FAILED) {
            throw std::invalid_argument("Invalid state code");
        }
        
        // Invariant: completed layers don't include current or future
        for (size_t layer : completed_layers_) {
            if (layer >= layer_index_) {
                throw std::invalid_argument(
                    "Completed layers must be before current layer index");
            }
        }
        
        // Invariant: pending operations is non-negative (implicit via size_t)
    }

public:
    SessionState(uint64_t session_id, size_t layer_index = 0)
        : session_id_(session_id), state_(INIT), 
          layer_index_(layer_index), pending_operations_(0) {
        check_invariants();
    }
    
    // Accessors
    uint64_t session_id() const { return session_id_; }
    StateCode state() const { return state_; }
    size_t layer_index() const { return layer_index_; }
    const std::set<size_t>& completed_layers() const { return completed_layers_; }
    size_t pending_operations() const { return pending_operations_; }
    
    // State transitions following operations.zpp
    void set_state(StateCode new_state) {
        state_ = new_state;
        check_invariants();
    }
    
    void advance_layer() {
        completed_layers_.insert(layer_index_);
        layer_index_++;
        check_invariants();
    }
    
    void increment_pending() {
        pending_operations_++;
    }
    
    void decrement_pending() {
        if (pending_operations_ == 0) {
            throw std::logic_error("Cannot decrement pending operations below 0");
        }
        pending_operations_--;
    }
};
```

### 1.3 Priority Queue Implementation

Based on `system_state.zpp`:

```cpp
#include <queue>
#include <functional>

template<typename T>
class PriorityQueue {
private:
    struct QueueEntry {
        T item;
        int priority;
        
        // Higher priority value = higher priority (processed first)
        bool operator<(const QueueEntry& other) const {
            return priority < other.priority;  // Note: reversed for max-heap
        }
    };
    
    std::priority_queue<QueueEntry> queue_;
    size_t capacity_;
    
    void check_invariants() const {
        // Invariant: size doesn't exceed capacity
        if (queue_.size() > capacity_) {
            throw std::logic_error("Queue size exceeds capacity");
        }
    }

public:
    explicit PriorityQueue(size_t capacity) : capacity_(capacity) {}
    
    bool enqueue(T item, int priority) {
        // Precondition: queue not full
        if (queue_.size() >= capacity_) {
            return false;
        }
        
        queue_.push({std::move(item), priority});
        check_invariants();
        return true;
    }
    
    bool dequeue(T& item) {
        // Precondition: queue not empty
        if (queue_.empty()) {
            return false;
        }
        
        item = std::move(queue_.top().item);
        queue_.pop();
        check_invariants();
        return true;
    }
    
    bool is_empty() const { return queue_.empty(); }
    bool is_full() const { return queue_.size() >= capacity_; }
    size_t size() const { return queue_.size(); }
    size_t capacity() const { return capacity_; }
};
```

## Part 2: Implementing NeuralReactor

### 2.1 Basic Reactor Structure

Based on `system_state.zpp`, NeuralReactor contains:
- Multiple priority queues (internal, external, command)
- Hash maps for sessions and arrays
- Rank and configuration

```cpp
#include <thread>
#include <atomic>
#include <unordered_map>
#include <memory>

enum class Rank { worker, manager, director };

class NeuralReactor {
private:
    uint64_t reactor_id_;
    Rank rank_;
    std::atomic<bool> is_running_;
    
    // Multiple event sources (as per formal spec)
    PriorityQueue<std::shared_ptr<Message>> internal_queue_;
    PriorityQueue<std::shared_ptr<Message>> external_queue_;
    PriorityQueue<std::shared_ptr<Command>> command_queue_;
    
    // State storage
    std::unordered_map<uint64_t, SessionState> session_map_;
    std::unordered_map<uint64_t, NDArray> ndarray_map_;
    
    // Configuration
    size_t max_queue_size_;
    size_t max_sessions_;
    
    std::thread reactor_thread_;
    
    void check_invariants() const {
        // Invariant: queue sizes within bounds
        if (internal_queue_.size() > max_queue_size_ ||
            external_queue_.size() > max_queue_size_ ||
            command_queue_.size() > max_queue_size_) {
            throw std::logic_error("Queue size exceeds maximum");
        }
        
        // Invariant: session count within bounds
        if (session_map_.size() > max_sessions_) {
            throw std::logic_error("Session count exceeds maximum");
        }
    }
    
    // Main event loop - processes from four sources
    void run_loop() {
        while (is_running_) {
            // Priority order as per system_state.zpp:
            // 1. Internal queue (highest priority)
            // 2. External queue
            // 3. Command queue
            // 4. GPU events
            // 5. Database events
            
            if (!process_internal_queue()) {
                if (!process_external_queue()) {
                    if (!process_command_queue()) {
                        if (!process_gpu_events()) {
                            process_database_events();
                        }
                    }
                }
            }
            
            check_invariants();
        }
    }
    
    bool process_internal_queue() {
        std::shared_ptr<Message> msg;
        if (internal_queue_.dequeue(msg)) {
            handle_message(*msg);
            return true;
        }
        return false;
    }
    
    bool process_external_queue() {
        std::shared_ptr<Message> msg;
        if (external_queue_.dequeue(msg)) {
            handle_message(*msg);
            return true;
        }
        return false;
    }
    
    bool process_command_queue() {
        std::shared_ptr<Command> cmd;
        if (command_queue_.dequeue(cmd)) {
            cmd->execute(this);
            return true;
        }
        return false;
    }
    
    bool process_gpu_events() {
        // Implementation depends on GPU integration
        return false;
    }
    
    bool process_database_events() {
        // Implementation depends on database integration
        return false;
    }
    
    void handle_message(const Message& msg) {
        // Handle different message types
        // Implementation based on operations.zpp
    }

public:
    NeuralReactor(uint64_t id, Rank rank, size_t max_queue_size, size_t max_sessions)
        : reactor_id_(id), rank_(rank), is_running_(false),
          internal_queue_(max_queue_size),
          external_queue_(max_queue_size),
          command_queue_(max_queue_size),
          max_queue_size_(max_queue_size),
          max_sessions_(max_sessions) {
        check_invariants();
    }
    
    // StartReactor operation from operations.zpp
    void start() {
        // Precondition: not already running
        if (is_running_) {
            throw std::logic_error("Reactor already running");
        }
        
        is_running_ = true;
        reactor_thread_ = std::thread(&NeuralReactor::run_loop, this);
        
        // Postcondition: is_running is true
        check_invariants();
    }
    
    // StopReactor operation from operations.zpp
    void stop() {
        // Precondition: reactor is running
        if (!is_running_) {
            throw std::logic_error("Reactor not running");
        }
        
        is_running_ = false;
        if (reactor_thread_.joinable()) {
            reactor_thread_.join();
        }
        
        // Postcondition: is_running is false, queues may still have items
        check_invariants();
    }
    
    // EnqueueCommand operation from operations.zpp
    bool enqueue_command(std::shared_ptr<Command> cmd, int priority) {
        // Precondition: reactor is running and queue not full
        if (!is_running_) {
            return false;
        }
        
        bool success = command_queue_.enqueue(cmd, priority);
        
        // Postcondition: if successful, command is in queue
        check_invariants();
        return success;
    }
    
    // Session state accessors
    SessionState* get_session(uint64_t session_id) {
        auto it = session_map_.find(session_id);
        return (it != session_map_.end()) ? &it->second : nullptr;
    }
    
    bool create_session(uint64_t session_id) {
        // Precondition: session doesn't exist and capacity available
        if (session_map_.count(session_id) > 0 || 
            session_map_.size() >= max_sessions_) {
            return false;
        }
        
        session_map_.emplace(session_id, SessionState(session_id));
        check_invariants();
        return true;
    }
};
```

## Part 3: Implementing Operations

### 3.1 CreateSession Operation

Following `operations.zpp` CreateSession specification:

```cpp
class SessionInitiator {
private:
    uint64_t initiator_id_;
    std::vector<NeuralReactor*> available_reactors_;
    std::set<uint64_t> active_sessions_;
    std::atomic<uint64_t> next_session_id_;

public:
    // CreateSession from operations.zpp
    uint64_t create_session(const std::vector<uint64_t>& layer_ids) {
        // Precondition: at least one reactor available
        if (available_reactors_.empty()) {
            throw std::logic_error("No reactors available");
        }
        
        // Precondition: layer sequence is valid and non-empty
        if (layer_ids.empty()) {
            throw std::invalid_argument("Layer sequence cannot be empty");
        }
        
        // Generate unique session ID
        uint64_t session_id = next_session_id_++;
        
        // Precondition: session ID is unique (guaranteed by atomic increment)
        
        // Select reactor (simple round-robin for now)
        NeuralReactor* reactor = available_reactors_[session_id % available_reactors_.size()];
        
        // Create session in reactor
        if (!reactor->create_session(session_id)) {
            throw std::runtime_error("Failed to create session in reactor");
        }
        
        // Add to active sessions
        active_sessions_.insert(session_id);
        
        // Postcondition: session added to active sessions
        // Postcondition: session exists in reactor with INIT state
        
        return session_id;
    }
};
```

### 3.2 ExecuteFeedForward Operation

Following `operations.zpp` ExecuteFeedForward specification:

```cpp
class FeedForward : public Command {
private:
    uint64_t session_id_;
    uint64_t layer_id_;
    Rank rank_;

public:
    FeedForward(uint64_t session_id, uint64_t layer_id, Rank rank)
        : session_id_(session_id), layer_id_(layer_id), rank_(rank) {}
    
    void execute(NeuralReactor* reactor) override {
        // Precondition: session exists
        SessionState* session = reactor->get_session(session_id_);
        if (!session) {
            throw std::logic_error("Session does not exist");
        }
        
        // Precondition: session is not in FAILED state
        if (session->state() == StateCode::FAILED) {
            throw std::logic_error("Cannot execute on failed session");
        }
        
        // Perform feedforward computation
        // (Simplified - actual implementation would involve layer computation)
        
        // Update session state
        session->set_state(StateCode::PROCESSING);
        
        // Simulate async GPU operation
        session->increment_pending();
        session->set_state(StateCode::WAITING_GPU);
        
        // In real implementation, would submit GPU operation here
        // which would eventually trigger GPU event processing
        
        // Postcondition: pending_operations incremented
        // Postcondition: state updated to WAITING_GPU
    }
};
```

## Part 4: Testing Against Formal Specifications

### 4.1 Invariant-Based Testing

Use formal invariants as test assertions:

```cpp
#include <cassert>

void test_ndarray_invariants() {
    // Test shape must be non-empty
    try {
        NDArray arr({}, Device::CPU, DataType::float32);
        assert(false && "Should have thrown exception for empty shape");
    } catch (const std::invalid_argument&) {
        // Expected
    }
    
    // Test all dimensions must be positive
    try {
        NDArray arr({2, 0, 3}, Device::CPU, DataType::float32);
        assert(false && "Should have thrown for zero dimension");
    } catch (const std::invalid_argument&) {
        // Expected
    }
    
    // Test valid array
    NDArray arr({2, 3, 4}, Device::CPU, DataType::float32);
    assert(arr.data().size() == 24);
}

void test_session_state_invariants() {
    SessionState session(123);
    
    // Test initial state
    assert(session.state() == StateCode::INIT);
    assert(session.layer_index() == 0);
    assert(session.completed_layers().empty());
    assert(session.pending_operations() == 0);
    
    // Test advance layer maintains invariant
    session.advance_layer();
    assert(session.layer_index() == 1);
    assert(session.completed_layers().count(0) == 1);
    
    // Test completed layers invariant
    assert(session.completed_layers().count(1) == 0);  // Current layer not in completed
}
```

### 4.2 Operation Precondition/Postcondition Testing

```cpp
void test_create_session_operation() {
    SessionInitiator initiator;
    NeuralReactor reactor(1, Rank::worker, 100, 10);
    reactor.start();
    
    std::vector<uint64_t> layers = {1, 2, 3};
    
    // Test precondition: layer sequence non-empty
    try {
        initiator.create_session({});
        assert(false && "Should require non-empty layer sequence");
    } catch (const std::invalid_argument&) {
        // Expected
    }
    
    // Test successful creation
    uint64_t session_id = initiator.create_session(layers);
    
    // Verify postconditions
    SessionState* session = reactor.get_session(session_id);
    assert(session != nullptr);
    assert(session->state() == StateCode::INIT);
    assert(session->layer_index() == 0);
    
    reactor.stop();
}
```

## Part 5: Integration Implementation

### 5.1 GPU Integration

Based on `integrations.zpp` GPU contracts:

```cpp
// Simplified GPU integration interface
class GPUIntegration {
public:
    struct GPUOperation {
        enum class Type { MatrixMultiply, Activation, Gradient, MemoryCopy };
        
        uint64_t operation_id;
        Type type;
        std::vector<uint64_t> input_arrays;
        uint64_t output_array;
    };
    
    struct GPUResult {
        uint64_t operation_id;
        bool success;
        std::string error_message;
    };
    
    // SubmitGPUComputation from integrations.zpp
    bool submit_operation(const GPUOperation& op) {
        // Precondition: GPU has available memory
        // Precondition: input arrays exist
        
        // Submit to GPU stream
        // Return success/failure
        
        return true;
    }
    
    // CompleteGPUComputation from integrations.zpp
    bool poll_completion(GPUResult& result) {
        // Check for completed operations
        // Postcondition: if success, result arrays are updated
        
        return false;  // No operations completed
    }
};
```

## Summary

This implementation guide demonstrates how to:
1. Translate formal Z++ specifications into C++ code
2. Preserve invariants through constructor and method design
3. Implement operations following precondition/postcondition contracts
4. Test implementations against formal specifications
5. Structure integrations based on formal contracts

## Implementation Status

The following components have been implemented in `hypermind.hpp`:

### Completed ✅
- **Command Operations**: `BackPropagation`, `WeightUpdate`, `GradientComputation` commands
- **Error Handling**: `ErrorSeverity` enum, `IntegrationError` struct, error handling in `NeuralReactor`
- **GPU Integration**: `GPUOperation`, `GPUResult` structures, GPU event handling
- **Database Integration**: `DatabaseQuery`, `DatabaseResult` structures, database event handling
- **Performance Monitoring**: `PerformanceMetrics` struct, metrics collection
- **Network Communication**: `NetworkInterface` class with checksum validation
- **Integration Tests**: Test files for session lifecycle, multi-reactor communication, performance
- **Build System**: CMakeLists.txt and Makefile for compilation

### In Progress 🚧
- **Full Command Implementations**: Command execute() methods need complete implementation
- **GPU/Database Backends**: Full CUDA and PostgreSQL integration implementations
- **Network Serialization**: Complete message serialization/deserialization

## Next Steps

### High Priority
- Complete command `execute()` method implementations with actual neural network computations
- Implement NDArray class with GPU memory management
- Add full CUDA kernel implementations for matrix operations
- Implement PostgreSQL async query handling with connection pooling

### Medium Priority  
- Add comprehensive error recovery mechanisms
- Implement rate limiting and backpressure as specified in `integrations.zpp`
- Create real integration tests with actual test data
- Add performance benchmarking suite

### Low Priority
- Add distributed system integration tests across multiple machines
- Implement advanced optimization strategies (gradient clipping, momentum)
- Add model checkpointing and persistence
- Create visualization tools for monitoring

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on implementing these features.

## References

- `specs/data_model.zpp` - Data structure specifications
- `specs/system_state.zpp` - System state and invariants
- `specs/operations.zpp` - Operation specifications
- `specs/integrations.zpp` - Integration contracts
- `docs/architecture_overview.md` - Architecture diagrams and explanations
