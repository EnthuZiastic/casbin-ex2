# Suggested Commands for CasbinEx2 Development

## Development Commands

### Testing
```bash
mix test                           # Run all tests
mix test --cover                   # Run tests with coverage
mix test test/specific_test.exs    # Run specific test file
```

### Code Quality
```bash
mix credo                          # Run code analysis
mix credo --strict                 # Run strict code analysis
mix dialyzer                       # Run static analysis
mix format                         # Format code
mix format --check-formatted       # Check if code is formatted
```

### Documentation
```bash
mix docs                          # Generate documentation
mix hex.docs open                 # Open generated docs
```

### Dependencies
```bash
mix deps.get                      # Fetch dependencies
mix deps.compile                  # Compile dependencies
mix deps.update --all             # Update all dependencies
```

### Database (for Ecto adapter)
```bash
mix ecto.create                   # Create database
mix ecto.migrate                  # Run migrations
mix ecto.rollback                 # Rollback migrations
```

### Compilation
```bash
mix compile                       # Compile project
mix compile --warnings-as-errors  # Compile with strict warnings
```

### Interactive Development
```bash
iex -S mix                        # Start IEx with project loaded
```

## Common Development Workflow
1. `mix deps.get` - Ensure dependencies are fetched
2. `mix format` - Format code
3. `mix credo` - Check code quality
4. `mix test` - Run tests
5. `mix dialyzer` - Static analysis (first run takes time)

## Benchmarking
```bash
mix run -e "CasbinEx2.Benchmark.run_comprehensive_benchmarks()"
```