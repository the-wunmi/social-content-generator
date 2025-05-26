defmodule SocialContentGenerator.Repo.Migrations.AddMeetingPlatformsAndRemoveConfiguration do
  use Ecto.Migration

  def up do
    # Add meeting platform integrations using ON CONFLICT with WHERE clause for partial index
    execute """
    INSERT INTO integrations (name, provider, slug, description, logo, scopes, inserted_at, updated_at)
    VALUES
      ('Zoom', 'zoom', 'zoom', 'Zoom video conferencing platform', 'https://d24cgw3uvb9a9h.cloudfront.net/static/93516/image/new-zoom-logo.png', '{"meeting"}', NOW(), NOW()),
      ('Microsoft Teams', 'microsoft', 'microsoft-teams', 'Microsoft Teams video conferencing platform', 'https://upload.wikimedia.org/wikipedia/commons/c/c9/Microsoft_Office_Teams_%282018%E2%80%93present%29.svg', '{"meeting"}', NOW(), NOW()),
      ('Google Meet', 'google', 'google-meet', 'Google Meet video conferencing platform', 'https://fonts.gstatic.com/s/i/productlogos/meet_2020q4/v6/web-512dp/logo_meet_2020q4_color_2x_web_512dp.png', '{"meeting"}', NOW(), NOW())
    ON CONFLICT (slug) WHERE deleted_at IS NULL DO NOTHING
    """

    # Remove configuration column from meetings table
    alter table(:meetings) do
      remove :configuration
    end
  end

  def down do
    # Add configuration column back
    alter table(:meetings) do
      add :configuration, :map
    end

    # Remove meeting platform integrations
    execute """
    DELETE FROM integrations WHERE slug IN ('zoom', 'microsoft-teams', 'google-meet')
    """
  end
end
