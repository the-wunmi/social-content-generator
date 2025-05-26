defmodule Mix.Tasks.SetupEnv do
  @moduledoc """
  Mix task to help set up the .env file for development.

  ## Usage

      mix setup_env

  This will create a .env file with default values that you can customize.
  """

  use Mix.Task

  @shortdoc "Sets up the .env file for development"

  def run(_args) do
    env_content = """
    # Database Configuration
    POSTGRES_USER=postgres
    POSTGRES_PASSWORD=postgres
    POSTGRES_HOST=localhost
    POSTGRES_DB=social_content_generator_dev
    POSTGRES_PORT=5432
    POSTGRES_POOL_SIZE=10

    # Phoenix Configuration
    PORT=4000
    SECRET_KEY_BASE=#{generate_secret_key_base()}

    # OAuth Configuration (replace with your actual values)
    GOOGLE_CLIENT_ID=your_google_client_id
    GOOGLE_CLIENT_SECRET=your_google_client_secret
    GOOGLE_REDIRECT_URI=http://localhost:4000/auth/google/callback

    LINKEDIN_CLIENT_ID=your_linkedin_client_id
    LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
    LINKEDIN_REDIRECT_URI=http://localhost:4000/auth/linkedin/callback

    FACEBOOK_CLIENT_ID=your_facebook_client_id
    FACEBOOK_CLIENT_SECRET=your_facebook_client_secret
    FACEBOOK_REDIRECT_URI=http://localhost:4000/auth/facebook/callback

    # API Keys (replace with your actual values)
    RECALL_API_KEY=your_recall_api_key
    OPENAI_API_KEY=your_openai_api_key

    # AI Configuration (choose provider: openai or custom)
    OPENAI_MODEL=gpt-4
    OPENAI_MAX_TOKENS=500
    OPENAI_TEMPERATURE=0.7

    # Custom AI Provider Configuration (for non-OpenAI vendors)
    # AI_BASE_URL=https://your-ai-provider.com/v1
    #
    # Example configuration matching the TypeScript example:
    # AI_BASE_URL=https://your-vendor.openai.com/openai/deployments/your-deployment

    # Bot Configuration
    BOT_JOIN_OFFSET_MINUTES=5

    # SMTP Configuration (optional for development)
    # SMTP_HOST=smtp.gmail.com
    # SMTP_PORT=587
    # SMTP_USERNAME=your_email@gmail.com
    # SMTP_PASSWORD=your_app_password
    """

    case File.write(".env", env_content) do
      :ok ->
        Mix.shell().info("""
        ✅ Successfully created .env file!

        📝 Next steps:
        1. Edit the .env file and replace placeholder values with your actual credentials
        2. For OAuth integrations, you'll need to:
           - Create apps in Google, LinkedIn, and Facebook developer consoles
           - Get your client IDs and secrets
           - Set up redirect URIs
        3. For API keys, sign up for services like Recall.ai and OpenAI
        4. Run `mix deps.get` and `mix ecto.setup` to complete setup

        🔒 Important: Never commit your .env file to version control!
        """)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to create .env file: #{reason}")
    end
  end

  defp generate_secret_key_base do
    :crypto.strong_rand_bytes(64) |> Base.encode64()
  end
end
