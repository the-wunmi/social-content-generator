defmodule SocialContentGeneratorWeb.MeetingHTML do
  @moduledoc """
  This module contains pages rendered by MeetingController.

  See the `meeting_html` directory for all templates.
  """
  use SocialContentGeneratorWeb, :html

  embed_templates "meeting_html/*"

  @doc """
  Gets the platform name for display from an automation output.
  """
  def get_platform_name(automation_output) do
    case automation_output.automation.integration.provider do
      "linkedin" -> "LinkedIn"
      "facebook" -> "Facebook"
      "twitter" -> "Twitter"
      platform when is_binary(platform) -> String.capitalize(platform)
      _ -> "Social Media"
    end
  end
end
