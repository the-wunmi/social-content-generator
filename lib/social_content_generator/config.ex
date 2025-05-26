defmodule SocialContentGenerator.Config do
  @moduledoc """
  Configuration helper module for safely accessing environment variables.
  """

  @doc """
  Gets an environment variable and raises a helpful error if it's missing.
  """
  def get_env!(key, description \\ nil) do
    case System.get_env(key) do
      nil ->
        desc = if description, do: " (#{description})", else: ""

        raise """
        Environment variable #{key} is missing#{desc}.

        Please create a .env file in your project root with the required variables.
        You can use the following template:

        #{env_template()}
        """

      value ->
        value
    end
  end

  @doc """
  Gets an environment variable as an integer.
  """
  def get_env_int!(key, description \\ nil) do
    key
    |> get_env!(description)
    |> String.to_integer()
  end

  @doc """
  Gets an environment variable with a default value.
  """
  def get_env(key, default) do
    System.get_env(key) || default
  end

  @doc """
  Gets an environment variable as an integer with a default value.
  """
  def get_env_int(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  defp env_template do
    """
    # Database Configuration
    POSTGRES_USER=postgres
    POSTGRES_PASSWORD=postgres
    POSTGRES_HOST=localhost
    POSTGRES_DB=social_content_generator_dev
    POSTGRES_PORT=5432
    POSTGRES_POOL_SIZE=10

    # Phoenix Configuration
    PORT=4000
    SECRET_KEY_BASE=your_secret_key_base_here_generate_with_mix_phx_gen_secret

    # OAuth Configuration
    GOOGLE_CLIENT_ID=your_google_client_id
    GOOGLE_CLIENT_SECRET=your_google_client_secret
    GOOGLE_REDIRECT_URI=http://localhost:4000/auth/google/callback

    LINKEDIN_CLIENT_ID=your_linkedin_client_id
    LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
    LINKEDIN_REDIRECT_URI=http://localhost:4000/auth/linkedin/callback

    FACEBOOK_CLIENT_ID=your_facebook_client_id
    FACEBOOK_CLIENT_SECRET=your_facebook_client_secret
    FACEBOOK_REDIRECT_URI=http://localhost:4000/auth/facebook/callback

    # API Keys
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

    # SMTP Configuration (optional for development)
    SMTP_HOST=smtp.gmail.com
    SMTP_PORT=587
    SMTP_USERNAME=your_email@gmail.com
    SMTP_PASSWORD=your_app_password
    """
  end
end
