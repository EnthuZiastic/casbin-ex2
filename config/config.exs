import Config

# Git hooks configuration
if Mix.env() == :dev do
  config :git_hooks,
    auto_install: true,
    verbose: true,
    hooks: [
      pre_push: [
        tasks: [
          {:cmd, "mix format --check-formatted"},
          {:cmd, "mix credo --strict"},
          {:cmd, "mix dialyzer"}
        ]
      ]
    ]
end
