# Task Completion Checklist

When completing any development task in CasbinEx2, ensure the following steps are completed:

## Code Quality Checks
1. **Format Code**: Run `mix format` to ensure consistent formatting
2. **Code Analysis**: Run `mix credo` and address any issues
3. **Static Analysis**: Run `mix dialyzer` and fix any type issues
4. **Compilation**: Ensure `mix compile --warnings-as-errors` passes

## Testing Requirements
1. **Unit Tests**: Write comprehensive tests for new functionality
2. **Test Coverage**: Ensure tests cover edge cases and error conditions
3. **Test Execution**: Run `mix test` and ensure all tests pass
4. **Behavior Tests**: Test adapter behavior compliance if implementing adapters

## Documentation Standards
1. **Module Documentation**: Add `@moduledoc` with clear description
2. **Function Documentation**: Add `@doc` with examples for public functions
3. **Type Specifications**: Add `@spec` for all public functions
4. **Examples**: Include usage examples in documentation

## Implementation Standards
1. **Behavior Compliance**: Implement all required callbacks for behaviors
2. **Error Handling**: Provide consistent error handling with descriptive messages
3. **Input Validation**: Validate inputs and handle edge cases
4. **State Management**: Use appropriate structs for maintaining state

## Final Verification
1. **Integration Testing**: Test with real adapters and enforcers
2. **Performance Impact**: Consider performance implications of changes
3. **Backward Compatibility**: Ensure changes don't break existing APIs
4. **Documentation Generation**: Run `mix docs` to verify documentation builds