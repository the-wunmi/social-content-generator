defmodule SocialContentGenerator.Services.ApiClient do
  @moduledoc """
  Helper module for accessing API keys and configurations consistently.
  """

  @doc """
  Gets the Recall API key from application configuration.
  """
  def recall_api_key do
    Application.get_env(:social_content_generator, :api_keys)[:recall_api_key]
  end

  @doc """
  Gets the OpenAI API key from application configuration.
  """
  def openai_api_key do
    Application.get_env(:social_content_generator, :api_keys)[:openai_api_key]
  end

  @doc """
  Gets OAuth configuration for a specific provider.
  """
  def oauth_config(provider) when provider in [:google, :linkedin, :facebook] do
    Application.get_env(:social_content_generator, :oauth)[provider]
  end

  @doc """
  Gets bot configuration.
  """
  def bot_config do
    Application.get_env(:social_content_generator, :bot)
  end

  @doc """
  Gets the bot join offset in minutes.
  """
  def bot_join_offset_minutes do
    bot_config()[:join_offset_minutes]
  end
end
