# SocialContentGenerator

A Phoenix application for generating social media content with integrations for Google, LinkedIn, Facebook, and Recall.ai.

## Setup

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+
- PostgreSQL 14+
- Node.js 18+ (for assets)

### Environment Configuration

This project uses `dotenvy` for environment variable management. Follow these steps:

1. **Create your environment file:**
   ```bash
   mix setup_env
   ```
   This creates a `.env` file with default values and a generated secret key.

2. **Edit the `.env` file** with your actual credentials:
   - Database connection details
   - OAuth client IDs and secrets for Google, LinkedIn, Facebook
   - API keys for Recall.ai and OpenAI
   - SMTP settings (optional for development)

3. **Install dependencies and setup database:**
   ```bash
   mix setup
   ```

### Starting the Application

```bash
# Start Phoenix endpoint
mix phx.server

# Or start inside IEx
iex -S mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Integrations

The application supports the following integrations:

- **Google Auth** (`google-auth`) - OAuth authentication
- **Google Calendar** (`google-calendar`) - Calendar management  
- **LinkedIn** (`linkedin`) - Social media automation
- **Facebook** (`facebook`) - Social media automation
- **Recall** (`recall`) - Meeting recording and transcription

### Integration Scopes

- `auth` - Authentication capabilities
- `bot` - Bot/automated actions
- `automation` - Content automation
- `calendar` - Calendar access

## Development

### Database Operations

```bash
# Create and migrate database
mix ecto.setup

# Reset database
mix ecto.reset

# Run migrations
mix ecto.migrate

# Seed database with integrations
mix run priv/repo/seeds.exs
```

### Testing

```bash
mix test
```

## Environment Variables

Key environment variables (see `.env` file for complete list):

- `POSTGRES_*` - Database configuration
- `SECRET_KEY_BASE` - Phoenix secret key
- `GOOGLE_CLIENT_ID/SECRET` - Google OAuth
- `LINKEDIN_CLIENT_ID/SECRET` - LinkedIn OAuth  
- `FACEBOOK_CLIENT_ID/SECRET` - Facebook OAuth
- `RECALL_API_KEY` - Recall.ai integration
- `OPENAI_API_KEY` - OpenAI integration

**⚠️ Important:** Never commit your `.env` file to version control!

## Production Deployment

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
