import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :social_content_generator, SocialContentGenerator.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  database:
    System.get_env("POSTGRES_DB") ||
      "social_content_generator_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :social_content_generator, SocialContentGeneratorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "/EpS7YhgN2CHPcQPdk44BSfGSAd6xgOi0xmMWs4EMjhIp23zGoxqnFcJuGtXAXE2",
  server: false

# In test we don't send emails
config :social_content_generator, SocialContentGenerator.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure Oban for testing (disable background jobs)
config :social_content_generator, Oban,
  # testing: :inline,
  queues: false,
  plugins: false

# Test OAuth Configuration (use test values)
config :social_content_generator, :oauth,
  google: [
    client_id: System.get_env("GOOGLE_CLIENT_ID") || "test_google_client_id",
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET") || "test_google_client_secret",
    redirect_uri:
      System.get_env("GOOGLE_REDIRECT_URI") || "http://localhost:4002/auth/google/callback"
  ],
  linkedin: [
    client_id: System.get_env("LINKEDIN_CLIENT_ID") || "test_linkedin_client_id",
    client_secret: System.get_env("LINKEDIN_CLIENT_SECRET") || "test_linkedin_client_secret",
    redirect_uri:
      System.get_env("LINKEDIN_REDIRECT_URI") || "http://localhost:4002/auth/linkedin/callback"
  ],
  facebook: [
    client_id: System.get_env("FACEBOOK_CLIENT_ID") || "test_facebook_client_id",
    client_secret: System.get_env("FACEBOOK_CLIENT_SECRET") || "test_facebook_client_secret",
    redirect_uri:
      System.get_env("FACEBOOK_REDIRECT_URI") || "http://localhost:4002/auth/facebook/callback"
  ]

# Test API Keys
config :social_content_generator, :api_keys,
  recall_api_key: System.get_env("RECALL_API_KEY") || "test_recall_api_key",
  openai_api_key: System.get_env("OPENAI_API_KEY") || "test_openai_api_key"

# Test AI Configuration
config :social_content_generator, :ai,
  provider: "openai",
  openai_api_key: "test_openai_api_key",
  model: "gpt-4",
  max_tokens: 500,
  temperature: 0.7

# Bot configuration for testing
config :social_content_generator, :bot, join_offset_minutes: 1
