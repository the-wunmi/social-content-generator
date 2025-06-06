defmodule SocialContentGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :social_content_generator,
      version: "0.1.0",
      elixir: "~> 1.18.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SocialContentGenerator.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "1.7.21"},
      {:phoenix_ecto, "4.6.4"},
      {:ecto_sql, "3.12.1"},
      {:postgrex, "0.20.0"},
      {:phoenix_html, "4.2.1"},
      {:phoenix_live_reload, "1.6.0", only: :dev},
      {:phoenix_live_view, "1.0.12"},
      {:floki, "0.37.1", only: :test},
      {:phoenix_live_dashboard, "0.8.7"},
      {:esbuild, "0.9.0", runtime: Mix.env() == :dev},
      {:tailwind, "0.3.1", runtime: Mix.env() == :dev},
      {:swoosh, "1.19.1"},
      {:finch, "0.19.0"},
      {:telemetry_metrics, "1.1.0"},
      {:telemetry_poller, "1.2.0"},
      {:gettext, "0.26.2"},
      {:jason, "1.4.4"},
      {:dns_cluster, "0.2.0"},
      {:plug_cowboy, "2.7.3"},
      {:httpoison, "2.2.3"},
      {:oban, "2.19.4"},
      {:bandit, "1.6.11"},
      {:heroicons, "0.5.6"},
      {:dotenvy, "0.8.0"},
      # Development dependencies
      {:credo, "1.7.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.4.5", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "1.2.0", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      check: ["format", "credo", "dialyzer", "test"]
    ]
  end
end
