import Config

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :social_content_generator, SocialContentGeneratorWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: SocialContentGenerator.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Configure Oban for production
config :social_content_generator, Oban,
  repo: SocialContentGenerator.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [calendar: 10, default: 10, meetings: 10, bots: 10, email: 10, social_media: 10]

# OAuth Configuration
config :social_content_generator, :oauth,
  google: [
    client_id: System.get_env("GOOGLE_CLIENT_ID"),
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
    redirect_uri: System.get_env("GOOGLE_REDIRECT_URI")
  ],
  linkedin: [
    client_id: System.get_env("LINKEDIN_CLIENT_ID"),
    client_secret: System.get_env("LINKEDIN_CLIENT_SECRET"),
    redirect_uri: System.get_env("LINKEDIN_REDIRECT_URI")
  ],
  facebook: [
    client_id: System.get_env("FACEBOOK_CLIENT_ID"),
    client_secret: System.get_env("FACEBOOK_CLIENT_SECRET"),
    redirect_uri: System.get_env("FACEBOOK_REDIRECT_URI")
  ]

# API Keys for external services
config :social_content_generator, :api_keys,
  recall_api_key: System.get_env("RECALL_API_KEY"),
  openai_api_key: System.get_env("OPENAI_API_KEY")

# AI Configuration - supports OpenAI and other compatible vendors
config :social_content_generator, :ai,
  # API Configuration
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  base_url: System.get_env("OPENAI_BASE_URL"),
  # Model Configuration
  model: System.get_env("OPENAI_MODEL") || "gpt-4",
  max_tokens: String.to_integer(System.get_env("OPENAI_MAX_TOKENS") || "500"),
  temperature: String.to_float(System.get_env("OPENAI_TEMPERATURE") || "0.7")

# Bot configuration
config :social_content_generator, :bot,
  join_offset_minutes: String.to_integer(System.get_env("BOT_JOIN_OFFSET_MINUTES") || "5")

# SMTP Configuration for production
config :social_content_generator, SocialContentGenerator.Mailer,
  adapter: if(System.get_env("SMTP_HOST"), do: Swoosh.Adapters.SMTP, else: Swoosh.Adapters.Local),
  relay: System.get_env("SMTP_HOST"),
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :if_available,
  retries: 2,
  no_mx_lookups: false

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
