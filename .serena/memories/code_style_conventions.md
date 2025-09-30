# Code Style and Conventions

## Naming Conventions
- Modules: PascalCase (e.g., `CasbinEx2.Adapter.FileAdapter`)
- Functions: snake_case (e.g., `load_policy/2`, `add_policy/4`)
- Variables: snake_case (e.g., `file_path`, `base_adapter`)
- Constants: SCREAMING_SNAKE_CASE (minimal usage)
- Private functions: snake_case with `defp`

## Module Structure
- Module documentation with `@moduledoc`
- Behaviour implementation with `@behaviour`
- Type definitions with `@type`
- Function documentation with `@doc`
- Implementation order: public functions first, then private functions

## Documentation Standards
- Comprehensive module documentation
- Function documentation with examples
- Type specifications for all public functions
- Examples in docstrings using triple backticks

## Error Handling
- Consistent error tuples: `{:ok, result}` | `{:error, reason}`
- Descriptive error messages
- Use `rescue` for exception handling
- Validate inputs with guard clauses when appropriate

## Code Organization
- One behavior per file
- Separate concerns with clear module boundaries
- Use structs for adapter state management
- Implement all required callbacks from behaviors