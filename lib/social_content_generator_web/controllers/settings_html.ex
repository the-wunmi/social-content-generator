defmodule SocialContentGeneratorWeb.SettingsHTML do
  @moduledoc """
  This module contains pages rendered by SettingsController.

  See the `settings_html` directory for all templates.
  """
  use SocialContentGeneratorWeb, :html

  embed_templates "settings_html/*"
end
