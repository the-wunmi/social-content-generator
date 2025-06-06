# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Load environment variables from .env file if it exists
# This needs to be done early in the configuration process
if File.exists?(".env") do
  try do
    Dotenvy.source!([".env"])
  rescue
    UndefinedFunctionError ->
      # Dotenvy not available during compilation, skip loading
      :ok
  end
end

config :social_content_generator,
  ecto_repos: [SocialContentGenerator.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :social_content_generator, SocialContentGeneratorWeb.Endpoint,
  server: true,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [
      html: SocialContentGeneratorWeb.ErrorHTML,
      json: SocialContentGeneratorWeb.ErrorJSON
    ],
    layout: false
  ],
  pubsub_server: SocialContentGenerator.PubSub,
  live_view: [signing_salt: "Ej8Ej8Ej"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :social_content_generator, SocialContentGenerator.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  social_content_generator: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  social_content_generator: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban for background jobs
config :social_content_generator, Oban,
  repo: SocialContentGenerator.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, calendar: 10, meetings: 10, bots: 10]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
