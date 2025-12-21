# Contributing to HyperMind

Thank you for your interest in contributing to HyperMind! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Architecture Understanding](#architecture-understanding)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Code Review Process](#code-review-process)
- [Development Guidelines](#development-guidelines)

## Code of Conduct

Be respectful, inclusive, and professional in all interactions. We aim to create a welcoming environment for all contributors.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/hypermind.git
   cd hypermind
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/o9nn/hypermind.git
   ```

## Development Setup

### Prerequisites

- C++17 or later compiler (GCC 7+, Clang 5+, MSVC 2017+)
- CMake 3.15+ or GNU Make
- Google Test (for testing)
- Optional: CUDA Toolkit 11.0+ (for GPU support)
- Optional: PostgreSQL 12+ (for database support)

### Building

#### Using CMake

```bash
mkdir build && cd build
cmake ..
make -j$(nproc)
```

#### Using Make

```bash
make info    # Show build configuration
make test    # Build and run tests
```

### Running Tests

```bash
# CMake
cd build
ctest -V

# Make
make test
```

## Architecture Understanding

Before contributing, familiarize yourself with:

1. **[docs/architecture_overview.md](docs/architecture_overview.md)** - System architecture and design
2. **[specs/](specs/)** - Formal Z++ specifications
3. **[docs/implementation_guide.md](docs/implementation_guide.md)** - Implementation patterns
4. **[docs/test_generation_guide.md](docs/test_generation_guide.md)** - Testing approaches

### Key Concepts

- **Actor Model**: NeuralReactors are independent actors communicating via messages
- **Formal Specifications**: All implementations must match Z++ specs in `specs/`
- **Invariants**: Operations must preserve system invariants
- **Thread Safety**: No shared mutable state between actors

## Making Changes

### Choosing What to Work On

1. Check the [issue tracker](https://github.com/o9nn/hypermind/issues) for open issues
2. Look for issues labeled `good-first-issue` or `help-wanted`
3. Comment on the issue to indicate you're working on it
4. For new features, open an issue first to discuss the approach

### Development Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following these guidelines:
   - Match formal specifications in `specs/`
   - Maintain thread safety
   - Preserve system invariants
   - Add appropriate error handling
   - Update documentation if needed

3. **Follow the coding style**:
   - Use meaningful variable names
   - Add comments for complex logic
   - Follow existing code patterns
   - Use C++17 features appropriately

4. **Write tests** for your changes:
   - Add unit tests for new functions
   - Add integration tests for new features
   - Ensure tests match formal specifications
   - See [docs/test_generation_guide.md](docs/test_generation_guide.md)

5. **Build and test locally**:
   ```bash
   make clean
   make test
   ```

## Testing

### Test Requirements

All contributions must include appropriate tests:

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test component interactions
- **Invariant Tests**: Verify system invariants hold
- **Performance Tests**: For performance-critical code

### Test Organization

```
tests/
├── session_lifecycle_test.cpp    # Session management tests
├── multi_reactor_test.cpp        # Multi-reactor communication
└── performance_test.cpp          # Performance and metrics
```

### Writing Tests

Follow the pattern in existing test files:

```cpp
#include <gtest/gtest.h>
#include "../hypermind.hpp"

class MyFeatureTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Initialize test fixtures
    }
    
    void TearDown() override {
        // Clean up
    }
};

TEST_F(MyFeatureTest, TestDescription) {
    // Arrange
    // Act
    // Assert
}
```

## Submitting Changes

### Commit Guidelines

- Write clear, descriptive commit messages
- Use present tense ("Add feature" not "Added feature")
- Reference issue numbers when applicable
- Keep commits focused and atomic

### Commit Message Format

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what and why, not how.

- Bullet points are okay
- Use a dash or asterisk for bullets

Fixes #123
```

### Pull Request Process

1. **Update documentation** if you changed functionality
2. **Ensure all tests pass** locally
3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
4. **Open a Pull Request** on GitHub with:
   - Clear description of changes
   - Reference to related issues
   - Screenshots (if UI changes)
   - Test results

### Pull Request Template

```markdown
## Description
Brief description of changes

## Related Issues
Fixes #123

## Changes Made
- Change 1
- Change 2

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] All tests pass locally
- [ ] Matches formal specifications

## Checklist
- [ ] Code follows project style
- [ ] Documentation updated
- [ ] Tests added
- [ ] Builds without warnings
```

## Code Review Process

1. **Automated checks** run on all PRs (when CI is set up)
2. **Maintainer review** - at least one maintainer approval required
3. **Address feedback** - respond to review comments
4. **Merge** - maintainer will merge when approved

### Review Criteria

- Matches formal specifications
- Maintains thread safety
- Preserves invariants
- Includes appropriate tests
- Clear, maintainable code
- Adequate documentation

## Development Guidelines

### Formal Specification Adherence

All implementations MUST match the formal specifications in `specs/`:

1. **Data Structures** (`specs/data_model.zpp`):
   - Implement all fields as specified
   - Maintain invariants in constructors
   - Add assertions for invariant checking

2. **Operations** (`specs/operations.zpp`):
   - Check preconditions before execution
   - Ensure postconditions after execution
   - Preserve global invariants

3. **Integrations** (`specs/integrations.zpp`):
   - Follow contract specifications
   - Handle all error cases
   - Implement rate limiting as specified

### Thread Safety

- **No shared mutable state** between actors
- **Message passing only** for inter-actor communication
- **Lock-free queues** for message passing
- **Actor state encapsulation** - only the owning actor modifies its state

### Error Handling

- Use `IntegrationError` for integration failures
- Implement proper error propagation
- Log errors with appropriate severity
- Include error recovery mechanisms

### Performance Considerations

- Minimize memory allocations in hot paths
- Use hash maps for O(1) lookups
- Avoid unnecessary copying of large arrays
- Profile before optimizing

### Documentation

- Update architecture diagrams if changing structure
- Update formal specifications if changing contracts
- Add code comments for complex logic
- Update README if changing user-facing features

## Questions?

- Open an issue for questions about contributing
- Check existing documentation in `docs/`
- Review formal specifications in `specs/`
- Look at the [GitHub Discussions](https://github.com/o9nn/hypermind/discussions)

## Thank You!

Your contributions help make HyperMind better for everyone. We appreciate your time and effort!
