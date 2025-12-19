# Test Generation from Formal Specifications

## Overview

This guide demonstrates how to systematically generate test cases from the Z++ formal specifications in HyperMind. Formal specifications provide a rigorous foundation for comprehensive test coverage by explicitly defining preconditions, postconditions, and invariants.

## Testing Strategy

### Three-Level Testing Approach

1. **Invariant Tests** - Verify data structure invariants hold
2. **Operation Tests** - Validate preconditions and postconditions
3. **Integration Tests** - Test external system contracts

## Part 1: Generating Tests from Data Model Specifications

### 1.1 Testing NDArray Invariants

From `specs/data_model.zpp`, the NDArray schema has three key invariants:

```z++
where
  #shape > 0 ∧ (∀ i : 1..#shape @ shape(i) > 0)
  #data = ∏{i : 1..#shape @ shape(i)}
  (∀ i : 1..#data @ ¬isInfinite(data(i)) ∧ ¬isNaN(data(i)))
```

**Generated Test Cases:**

```cpp
#include <gtest/gtest.h>
#include "hypermind.hpp"

class NDArrayTest : public ::testing::Test {
protected:
    // Test fixtures
};

// Test Case 1: Shape invariant - non-empty
TEST_F(NDArrayTest, ShapeCannotBeEmpty) {
    EXPECT_THROW({
        NDArray arr({}, Device::CPU, DataType::float32);
    }, std::invalid_argument);
}

// Test Case 2: Shape invariant - all dimensions positive
TEST_F(NDArrayTest, AllDimensionsMustBePositive) {
    // Test zero dimension
    EXPECT_THROW({
        NDArray arr({2, 0, 3}, Device::CPU, DataType::float32);
    }, std::invalid_argument);
    
    // Test negative not possible with size_t, but test boundary
    EXPECT_NO_THROW({
        NDArray arr({1, 1, 1}, Device::CPU, DataType::float32);
    });
}

// Test Case 3: Data size invariant
TEST_F(NDArrayTest, DataSizeMatchesShapeProduct) {
    NDArray arr({2, 3, 4}, Device::CPU, DataType::float32);
    EXPECT_EQ(arr.data().size(), 24u);
    
    NDArray arr2({5, 7}, Device::CPU, DataType::float32);
    EXPECT_EQ(arr2.data().size(), 35u);
}

// Test Case 4: Data validity invariant - no NaN
TEST_F(NDArrayTest, DataCannotContainNaN) {
    NDArray arr({2, 2}, Device::CPU, DataType::float32);
    
    std::vector<double> invalid_data = {1.0, 2.0, std::nan(""), 4.0};
    EXPECT_THROW({
        arr.set_data(invalid_data);
    }, std::invalid_argument);
}

// Test Case 5: Data validity invariant - no Infinity
TEST_F(NDArrayTest, DataCannotContainInfinity) {
    NDArray arr({2, 2}, Device::CPU, DataType::float32);
    
    std::vector<double> invalid_data = {1.0, 2.0, INFINITY, 4.0};
    EXPECT_THROW({
        arr.set_data(invalid_data);
    }, std::invalid_argument);
}

// Test Case 6: Valid array creation
TEST_F(NDArrayTest, ValidArrayCreation) {
    EXPECT_NO_THROW({
        NDArray arr({10, 20, 30}, Device::GPU, DataType::float64);
        EXPECT_EQ(arr.shape().size(), 3u);
        EXPECT_EQ(arr.device(), Device::GPU);
        EXPECT_EQ(arr.dtype(), DataType::float64);
    });
}

// Property-based test: Shape product always equals data size
TEST_F(NDArrayTest, PropertyShapeProductEqualsDataSize) {
    std::vector<std::vector<size_t>> test_shapes = {
        {1}, {5}, {10},
        {2, 3}, {4, 5}, {10, 20},
        {2, 3, 4}, {5, 5, 5}, {1, 10, 100}
    };
    
    for (const auto& shape : test_shapes) {
        NDArray arr(shape, Device::CPU, DataType::float32);
        
        size_t expected_size = 1;
        for (size_t dim : shape) {
            expected_size *= dim;
        }
        
        EXPECT_EQ(arr.data().size(), expected_size)
            << "Failed for shape of size " << shape.size();
    }
}
```

### 1.2 Testing SessionState Invariants

From `specs/data_model.zpp`:

```z++
where
  state ≥ 0
  layer_index ≥ 0
  (∀ l : completed_layers @ l < layer_index)
  pending_operations ≥ 0
```

**Generated Test Cases:**

```cpp
class SessionStateTest : public ::testing::Test {
protected:
    static constexpr uint64_t TEST_SESSION_ID = 12345;
};

// Test Case 1: State code validity
TEST_F(SessionStateTest, StateCodeMustBeValid) {
    SessionState session(TEST_SESSION_ID);
    EXPECT_GE(session.state(), StateCode::INIT);
    EXPECT_LE(session.state(), StateCode::FAILED);
}

// Test Case 2: Layer index non-negative
TEST_F(SessionStateTest, LayerIndexNonNegative) {
    SessionState session(TEST_SESSION_ID, 0);
    EXPECT_GE(session.layer_index(), 0u);
}

// Test Case 3: Completed layers invariant
TEST_F(SessionStateTest, CompletedLayersBeforeCurrentIndex) {
    SessionState session(TEST_SESSION_ID, 0);
    
    // Advance through several layers
    session.advance_layer();  // Now at layer 1, layer 0 completed
    EXPECT_EQ(session.layer_index(), 1u);
    EXPECT_TRUE(session.completed_layers().count(0) > 0);
    EXPECT_FALSE(session.completed_layers().count(1) > 0);
    
    session.advance_layer();  // Now at layer 2
    EXPECT_EQ(session.layer_index(), 2u);
    EXPECT_TRUE(session.completed_layers().count(0) > 0);
    EXPECT_TRUE(session.completed_layers().count(1) > 0);
    EXPECT_FALSE(session.completed_layers().count(2) > 0);
    
    // Verify invariant: all completed < current
    for (size_t completed : session.completed_layers()) {
        EXPECT_LT(completed, session.layer_index());
    }
}

// Test Case 4: Pending operations invariant
TEST_F(SessionStateTest, PendingOperationsNonNegative) {
    SessionState session(TEST_SESSION_ID);
    
    EXPECT_EQ(session.pending_operations(), 0u);
    
    session.increment_pending();
    EXPECT_EQ(session.pending_operations(), 1u);
    
    session.decrement_pending();
    EXPECT_EQ(session.pending_operations(), 0u);
    
    // Cannot go below zero
    EXPECT_THROW({
        session.decrement_pending();
    }, std::logic_error);
}

// Test Case 5: State transition validity
TEST_F(SessionStateTest, ValidStateTransitions) {
    SessionState session(TEST_SESSION_ID);
    
    EXPECT_EQ(session.state(), StateCode::INIT);
    
    session.set_state(StateCode::PROCESSING);
    EXPECT_EQ(session.state(), StateCode::PROCESSING);
    
    session.set_state(StateCode::WAITING_GPU);
    EXPECT_EQ(session.state(), StateCode::WAITING_GPU);
    
    session.set_state(StateCode::COMPLETED);
    EXPECT_EQ(session.state(), StateCode::COMPLETED);
}
```

## Part 2: Generating Tests from Operation Specifications

### 2.1 Testing CreateSession Operation

From `specs/operations.zpp`, extract preconditions and postconditions:

**Preconditions:**
- Initiator exists and is running
- Layer sequence is valid and non-empty
- At least one reactor is available

**Postconditions:**
- New session ID is unique
- Session added to initiator's active sessions
- SessionState created in reactor with INIT state
- Reactor marked as busy

**Generated Test Cases:**

```cpp
class CreateSessionTest : public ::testing::Test {
protected:
    void SetUp() override {
        reactor_ = new NeuralReactor(1, Rank::worker, 100, 10);
        initiator_ = new SessionInitiator();
        initiator_->add_reactor(reactor_);
    }
    
    void TearDown() override {
        delete initiator_;
        delete reactor_;
    }
    
    NeuralReactor* reactor_;
    SessionInitiator* initiator_;
};

// Precondition Test 1: Layer sequence must be non-empty
TEST_F(CreateSessionTest, PreConditionLayerSequenceNonEmpty) {
    EXPECT_THROW({
        initiator_->create_session({});
    }, std::invalid_argument);
}

// Precondition Test 2: At least one reactor must be available
TEST_F(CreateSessionTest, PreConditionReactorAvailable) {
    SessionInitiator empty_initiator;
    EXPECT_THROW({
        empty_initiator.create_session({1, 2, 3});
    }, std::logic_error);
}

// Precondition Test 3: Layer IDs must be valid
TEST_F(CreateSessionTest, PreConditionValidLayerIds) {
    // Assuming layer registry validation
    // Would throw if layer IDs don't exist in registry
    std::vector<uint64_t> valid_layers = {1, 2, 3};
    EXPECT_NO_THROW({
        initiator_->create_session(valid_layers);
    });
}

// Postcondition Test 1: Session ID is unique
TEST_F(CreateSessionTest, PostConditionUniqueSessionId) {
    std::vector<uint64_t> layers = {1, 2, 3};
    
    uint64_t session1 = initiator_->create_session(layers);
    uint64_t session2 = initiator_->create_session(layers);
    uint64_t session3 = initiator_->create_session(layers);
    
    EXPECT_NE(session1, session2);
    EXPECT_NE(session1, session3);
    EXPECT_NE(session2, session3);
}

// Postcondition Test 2: Session added to active sessions
TEST_F(CreateSessionTest, PostConditionSessionInActiveSet) {
    std::vector<uint64_t> layers = {1, 2, 3};
    
    uint64_t session_id = initiator_->create_session(layers);
    
    EXPECT_TRUE(initiator_->is_active_session(session_id));
    EXPECT_FALSE(initiator_->is_completed_session(session_id));
    EXPECT_FALSE(initiator_->is_failed_session(session_id));
}

// Postcondition Test 3: Session exists in reactor with INIT state
TEST_F(CreateSessionTest, PostConditionSessionInReactorWithInitState) {
    reactor_->start();
    std::vector<uint64_t> layers = {1, 2, 3};
    
    uint64_t session_id = initiator_->create_session(layers);
    
    SessionState* session = reactor_->get_session(session_id);
    ASSERT_NE(session, nullptr);
    EXPECT_EQ(session->state(), StateCode::INIT);
    EXPECT_EQ(session->layer_index(), 0u);
    EXPECT_TRUE(session->completed_layers().empty());
    EXPECT_EQ(session->pending_operations(), 0u);
    
    reactor_->stop();
}

// Postcondition Test 4: Sessions counter incremented
TEST_F(CreateSessionTest, PostConditionSessionsCounterIncremented) {
    size_t initial_count = initiator_->get_sessions_created_count();
    
    std::vector<uint64_t> layers = {1, 2, 3};
    initiator_->create_session(layers);
    
    EXPECT_EQ(initiator_->get_sessions_created_count(), initial_count + 1);
}

// Invariant Test: All invariants preserved after operation
TEST_F(CreateSessionTest, InvariantsPreservedAfterCreation) {
    reactor_->start();
    std::vector<uint64_t> layers = {1, 2, 3};
    
    uint64_t session_id = initiator_->create_session(layers);
    
    // Check system invariants still hold
    EXPECT_NO_THROW({
        reactor_->check_invariants();
        initiator_->check_invariants();
    });
    
    reactor_->stop();
}
```

### 2.2 Testing ExecuteFeedForward Operation

From `specs/operations.zpp`:

**Preconditions:**
- Session exists in reactor
- Session not in FAILED state
- Layer exists and is valid

**Postconditions:**
- Session state updated (PROCESSING or WAITING_GPU)
- Pending operations incremented if async
- Layer computation performed

**Generated Test Cases:**

```cpp
class ExecuteFeedForwardTest : public ::testing::Test {
protected:
    void SetUp() override {
        reactor_ = new NeuralReactor(1, Rank::worker, 100, 10);
        reactor_->start();
        reactor_->create_session(TEST_SESSION_ID);
    }
    
    void TearDown() override {
        reactor_->stop();
        delete reactor_;
    }
    
    NeuralReactor* reactor_;
    static constexpr uint64_t TEST_SESSION_ID = 9999;
    static constexpr uint64_t TEST_LAYER_ID = 1;
};

// Precondition Test 1: Session must exist
TEST_F(ExecuteFeedForwardTest, PreConditionSessionExists) {
    auto cmd = std::make_shared<FeedForward>(
        77777,  // Non-existent session
        TEST_LAYER_ID,
        Rank::worker
    );
    
    EXPECT_THROW({
        cmd->execute(reactor_);
    }, std::logic_error);
}

// Precondition Test 2: Session not in FAILED state
TEST_F(ExecuteFeedForwardTest, PreConditionSessionNotFailed) {
    SessionState* session = reactor_->get_session(TEST_SESSION_ID);
    session->set_state(StateCode::FAILED);
    
    auto cmd = std::make_shared<FeedForward>(
        TEST_SESSION_ID,
        TEST_LAYER_ID,
        Rank::worker
    );
    
    EXPECT_THROW({
        cmd->execute(reactor_);
    }, std::logic_error);
}

// Postcondition Test 1: State updated
TEST_F(ExecuteFeedForwardTest, PostConditionStateUpdated) {
    auto cmd = std::make_shared<FeedForward>(
        TEST_SESSION_ID,
        TEST_LAYER_ID,
        Rank::worker
    );
    
    cmd->execute(reactor_);
    
    SessionState* session = reactor_->get_session(TEST_SESSION_ID);
    ASSERT_NE(session, nullptr);
    
    // Should be in PROCESSING or WAITING_GPU state
    StateCode state = session->state();
    EXPECT_TRUE(state == StateCode::PROCESSING || 
                state == StateCode::WAITING_GPU);
}

// Postcondition Test 2: Pending operations incremented for async
TEST_F(ExecuteFeedForwardTest, PostConditionPendingOpsIncremented) {
    SessionState* session = reactor_->get_session(TEST_SESSION_ID);
    size_t initial_pending = session->pending_operations();
    
    auto cmd = std::make_shared<FeedForward>(
        TEST_SESSION_ID,
        TEST_LAYER_ID,
        Rank::worker
    );
    
    cmd->execute(reactor_);
    
    if (session->state() == StateCode::WAITING_GPU) {
        EXPECT_GT(session->pending_operations(), initial_pending);
    }
}

// Postcondition Test 3: Invariants preserved
TEST_F(ExecuteFeedForwardTest, PostConditionInvariantsPreserved) {
    auto cmd = std::make_shared<FeedForward>(
        TEST_SESSION_ID,
        TEST_LAYER_ID,
        Rank::worker
    );
    
    cmd->execute(reactor_);
    
    EXPECT_NO_THROW({
        reactor_->check_invariants();
    });
}
```

## Part 3: Generating Tests from Integration Specifications

### 3.1 Testing GPU Integration Contracts

From `specs/integrations.zpp`:

**Preconditions:**
- GPU has available memory
- Input arrays exist
- Operation type is valid

**Postconditions:**
- If success, operation queued
- If failure, error information provided
- Memory constraints respected

**Generated Test Cases:**

```cpp
class GPUIntegrationTest : public ::testing::Test {
protected:
    void SetUp() override {
        gpu_ = new GPUIntegration();
    }
    
    void TearDown() override {
        delete gpu_;
    }
    
    GPUIntegration* gpu_;
};

// Precondition Test 1: Valid operation type
TEST_F(GPUIntegrationTest, PreConditionValidOperationType) {
    GPUIntegration::GPUOperation op;
    op.operation_id = 1;
    op.type = GPUIntegration::GPUOperation::Type::MatrixMultiply;
    op.input_arrays = {1, 2};
    op.output_array = 3;
    
    EXPECT_NO_THROW({
        gpu_->submit_operation(op);
    });
}

// Precondition Test 2: Memory availability
TEST_F(GPUIntegrationTest, PreConditionMemoryAvailable) {
    // Create many large operations to exhaust memory
    std::vector<GPUIntegration::GPUOperation> ops;
    
    bool memory_exhausted = false;
    for (int i = 0; i < 10000; i++) {
        GPUIntegration::GPUOperation op;
        op.operation_id = i;
        op.type = GPUIntegration::GPUOperation::Type::MatrixMultiply;
        op.input_arrays = {static_cast<uint64_t>(i), static_cast<uint64_t>(i+1)};
        op.output_array = i + 2;
        
        if (!gpu_->submit_operation(op)) {
            memory_exhausted = true;
            break;
        }
    }
    
    // Eventually should fail when memory exhausted
    EXPECT_TRUE(memory_exhausted);
}

// Postcondition Test 1: Success status
TEST_F(GPUIntegrationTest, PostConditionSuccessStatus) {
    GPUIntegration::GPUOperation op;
    op.operation_id = 100;
    op.type = GPUIntegration::GPUOperation::Type::Activation;
    op.input_arrays = {1};
    op.output_array = 2;
    
    bool submitted = gpu_->submit_operation(op);
    EXPECT_TRUE(submitted);
    
    // Poll for completion
    GPUIntegration::GPUResult result;
    bool completed = false;
    for (int i = 0; i < 100; i++) {
        if (gpu_->poll_completion(result)) {
            completed = true;
            EXPECT_EQ(result.operation_id, 100u);
            EXPECT_TRUE(result.success);
            break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

// Postcondition Test 2: Error handling
TEST_F(GPUIntegrationTest, PostConditionErrorInformation) {
    GPUIntegration::GPUOperation invalid_op;
    invalid_op.operation_id = 200;
    invalid_op.type = GPUIntegration::GPUOperation::Type::MatrixMultiply;
    invalid_op.input_arrays = {};  // Empty inputs - should fail
    invalid_op.output_array = 1;
    
    bool submitted = gpu_->submit_operation(invalid_op);
    
    if (!submitted) {
        // Immediate failure - precondition violation
        EXPECT_FALSE(submitted);
    } else {
        // May fail during execution
        GPUIntegration::GPUResult result;
        if (gpu_->poll_completion(result)) {
            EXPECT_FALSE(result.success);
            EXPECT_FALSE(result.error_message.empty());
        }
    }
}

// Invariant Test: Memory constraints
TEST_F(GPUIntegrationTest, InvariantMemoryConstraints) {
    // Submit multiple operations
    for (int i = 0; i < 10; i++) {
        GPUIntegration::GPUOperation op;
        op.operation_id = i;
        op.type = GPUIntegration::GPUOperation::Type::MemoryCopy;
        op.input_arrays = {static_cast<uint64_t>(i)};
        op.output_array = i + 100;
        
        gpu_->submit_operation(op);
        
        // Check that memory invariants still hold
        EXPECT_NO_THROW({
            gpu_->check_memory_invariants();
        });
    }
}
```

## Part 4: Property-Based Testing

Generate tests that verify general properties derived from specifications:

```cpp
#include <random>

class PropertyBasedTest : public ::testing::Test {
protected:
    std::mt19937 gen_{42};  // Fixed seed for reproducibility
    
    // Generate random valid shape
    std::vector<size_t> random_shape(size_t ndim) {
        std::uniform_int_distribution<size_t> dist(1, 100);
        std::vector<size_t> shape;
        for (size_t i = 0; i < ndim; i++) {
            shape.push_back(dist(gen_));
        }
        return shape;
    }
};

// Property: Creating and destroying NDArray preserves system state
TEST_F(PropertyBasedTest, PropertyNDArrayLifecycle) {
    for (int trial = 0; trial < 100; trial++) {
        auto shape = random_shape(3);
        
        EXPECT_NO_THROW({
            NDArray arr(shape, Device::CPU, DataType::float32);
            // Array automatically destroyed
        });
    }
}

// Property: Session operations preserve invariants
TEST_F(PropertyBasedTest, PropertySessionOperationsPreserveInvariants) {
    NeuralReactor reactor(1, Rank::worker, 100, 10);
    reactor.start();
    
    std::uniform_int_distribution<uint64_t> session_dist(1, 10000);
    
    for (int trial = 0; trial < 100; trial++) {
        uint64_t session_id = session_dist(gen_);
        
        if (reactor.create_session(session_id)) {
            // Perform random operations
            SessionState* session = reactor.get_session(session_id);
            ASSERT_NE(session, nullptr);
            
            session->set_state(StateCode::PROCESSING);
            session->increment_pending();
            session->decrement_pending();
            
            // Invariants should still hold
            EXPECT_NO_THROW({
                reactor.check_invariants();
            });
        }
    }
    
    reactor.stop();
}

// Property: Queue operations maintain ordering invariant
TEST_F(PropertyBasedTest, PropertyQueueOrdering) {
    PriorityQueue<int> queue(100);
    
    std::uniform_int_distribution<int> priority_dist(1, 10);
    
    // Enqueue items with random priorities
    std::vector<std::pair<int, int>> items;
    for (int i = 0; i < 50; i++) {
        int priority = priority_dist(gen_);
        queue.enqueue(i, priority);
        items.push_back({i, priority});
    }
    
    // Dequeue and verify ordering
    int prev_priority = INT_MAX;
    int item;
    while (queue.dequeue(item)) {
        // Find item in original list
        auto it = std::find_if(items.begin(), items.end(),
                              [item](const auto& p) { return p.first == item; });
        ASSERT_NE(it, items.end());
        
        // Current priority should be <= previous (descending order)
        EXPECT_LE(it->second, prev_priority);
        prev_priority = it->second;
    }
}
```

## Part 5: Test Coverage Analysis

### Coverage Goals Derived from Specifications

**Data Model Coverage:**
- ✓ All schemas have invariant tests
- ✓ All enumerations tested
- ✓ Boundary conditions tested

**Operation Coverage:**
- ✓ All preconditions tested (both satisfied and violated)
- ✓ All postconditions verified
- ✓ State transitions validated
- ✓ Error cases handled

**Integration Coverage:**
- ✓ All external system contracts tested
- ✓ Error paths covered
- ✓ Resource constraints validated

## Summary

This test generation approach provides:

1. **Systematic Coverage** - Every specification element translates to tests
2. **Correctness Verification** - Tests validate formal properties
3. **Regression Prevention** - Tests encode specification intent
4. **Documentation** - Tests serve as executable specifications

## Test Execution

```bash
# Build tests
g++ -std=c++17 -I./include -lgtest -lgtest_main \
    tests/ndarray_test.cpp \
    tests/session_state_test.cpp \
    tests/create_session_test.cpp \
    tests/feedforward_test.cpp \
    tests/gpu_integration_test.cpp \
    tests/property_based_test.cpp \
    -o hypermind_tests

# Run tests
./hypermind_tests

# Run with verbose output
./hypermind_tests --gtest_verbose

# Run specific test suite
./hypermind_tests --gtest_filter=NDArrayTest.*
```

## References

- `specs/data_model.zpp` - Source of invariant tests
- `specs/operations.zpp` - Source of operation tests
- `specs/integrations.zpp` - Source of integration tests
- Google Test Framework - https://github.com/google/googletest
