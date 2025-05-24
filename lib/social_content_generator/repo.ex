defmodule SocialContentGenerator.Repo do
  use Ecto.Repo,
    otp_app: :social_content_generator,
    adapter: Ecto.Adapters.Postgres
end
