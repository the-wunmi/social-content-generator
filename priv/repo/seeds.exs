# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     SocialContentGenerator.Repo.insert!(%SocialContentGenerator.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias SocialContentGenerator.Repo
alias SocialContentGenerator.Integrations.Integration

# Create integrations with logos, scopes, and slugs
integrations = [
  %{
    name: "Google Auth",
    provider: "google",
    slug: "google-auth",
    description: "Google OAuth authentication integration",
    logo: "https://developers.google.com/identity/images/g-logo.png",
    scopes: ["auth"]
  },
  %{
    name: "Google Calendar",
    provider: "google",
    slug: "google-calendar",
    description: "Google Calendar integration for meeting management",
    logo: "https://developers.google.com/identity/images/g-logo.png",
    scopes: ["calendar"]
  },
  %{
    name: "LinkedIn",
    provider: "linkedin",
    slug: "linkedin",
    description: "LinkedIn social media integration",
    logo:
      "https://content.linkedin.com/content/dam/me/business/en-us/amp/brand-site/v2/bg/LI-Bug.svg.original.svg",
    scopes: ["automation"]
  },
  %{
    name: "Facebook",
    provider: "facebook",
    slug: "facebook",
    description: "Facebook social media integration",
    logo: "https://upload.wikimedia.org/wikipedia/commons/5/51/Facebook_f_logo_%282019%29.svg",
    scopes: ["automation"]
  },
  %{
    name: "Recall",
    provider: "recall",
    slug: "recall",
    description: "Recall meeting recording and transcription integration",
    logo: "https://www.recall.ai/favicon.ico",
    scopes: ["bot"]
  }
]

Enum.each(integrations, fn integration_attrs ->
  case Repo.get_by(Integration, slug: integration_attrs.slug) do
    nil ->
      %Integration{}
      |> Integration.changeset(integration_attrs)
      |> Repo.insert!()
      |> IO.inspect(label: "Created integration")

    existing ->
      existing
      |> Integration.changeset(integration_attrs)
      |> Repo.update!()
      |> IO.inspect(label: "Updated integration")
  end
end)
