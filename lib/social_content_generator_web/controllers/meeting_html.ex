defmodule SocialContentGeneratorWeb.MeetingHTML do
  @moduledoc """
  This module contains pages rendered by MeetingController.

  See the `meeting_html` directory for all templates.
  """
  use SocialContentGeneratorWeb, :html

  embed_templates "meeting_html/*"
end
