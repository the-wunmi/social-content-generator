defmodule SocialContentGeneratorWeb.Router do
  use SocialContentGeneratorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SocialContentGeneratorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug SocialContentGeneratorWeb.Plugs.Auth
  end

  scope "/", SocialContentGeneratorWeb do
    pipe_through :browser

    get "/", SessionController, :login
    get "/login", SessionController, :login
    delete "/logout", SessionController, :delete

    # Google OAuth for authentication
    get "/auth/google", OAuthController, :google_auth
    get "/auth/google/callback", OAuthController, :google_callback
  end

  scope "/", SocialContentGeneratorWeb do
    pipe_through [:browser, :auth]

    get "/settings", SettingsController, :index
    get "/settings/automations", SettingsController, :automations
    get "/settings/automations/new", SettingsController, :new_automation
    post "/settings/automations", SettingsController, :create_automation
    get "/settings/automations/:id/edit", SettingsController, :edit_automation
    put "/settings/automations/:id", SettingsController, :update_automation
    delete "/settings/automations/:id", SettingsController, :delete_automation

    # OAuth routes
    get "/auth/linkedin/callback", OAuthController, :linkedin_callback
    get "/auth/facebook/callback", OAuthController, :facebook_callback

    # Auth initiation routes
    get "/settings/linkedin/auth", SettingsController, :linkedin_auth
    get "/settings/facebook/auth", SettingsController, :facebook_auth

    # Calendar routes
    get "/calendar", CalendarController, :index
    get "/calendar/google", CalendarController, :connect_google_calendar
    get "/calendar/google/callback", CalendarController, :google_calendar_callback
    patch "/calendar/events/:id", CalendarController, :update

    # Meeting routes
    resources "/meetings", MeetingController, only: [:index, :show, :create]

    post "/meetings/:meeting_id/automations/:automation_id/generate_post",
         MeetingController,
         :generate_post
  end

  # Other scopes may use custom stacks.
  # scope "/api", SocialContentGeneratorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:social_content_generator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SocialContentGeneratorWeb.Telemetry
    end
  end
end
