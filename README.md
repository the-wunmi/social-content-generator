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

## Recall.ai Meeting Bot Integration

This application integrates with [Recall.ai](https://recall.ai) to automatically send note-taking bots to your meetings and generate social content from meeting transcripts.

### How it Works

1. **Calendar Integration**: Connect your Google Calendar to see upcoming meetings
2. **Bot Scheduling**: For meetings with video links (Zoom, Teams, Google Meet, etc.), enable the note taker
3. **Automatic Bot Deployment**: The app schedules Recall.ai bots to join meetings a configurable number of minutes before they start
4. **Transcript Processing**: After meetings end, bots provide transcripts with speaker identification
5. **Content Generation**: Transcripts are processed to generate social media posts and follow-up emails

### Supported Meeting Platforms

- **Zoom** - Full support with automatic bot joining
- **Microsoft Teams** - Full support with automatic bot joining  
- **Google Meet** - Full support with automatic bot joining
- **Cisco Webex** - Full support with automatic bot joining
- **Other platforms** - Basic support for any platform with meeting URLs

### Configuration

The bot join timing is configurable via environment variables:

```bash
# Bot will join 5 minutes before meeting starts (default)
BOT_JOIN_OFFSET_MINUTES=5
```

### Usage

1. **Connect Calendar**: Go to `/calendar` and connect your Google Calendar
2. **Enable Note Taker**: For any meeting with a video link, toggle the "Note Taker" switch
3. **Automatic Processing**: When meetings start, the app will automatically:
   - Create a meeting record in the system
   - Deploy a Recall.ai bot to join the meeting
   - Record and transcribe the conversation with speaker identification
   - Extract attendee information from the meeting
   - Generate meeting summaries and action items after completion
4. **View Results**: Check `/meetings` to see completed meetings with transcripts and generated content

### Bot Management

The application uses background workers to manage bot lifecycle:

- **BotWorker**: Handles bot creation and status polling
- **CalendarWorker**: Processes calendar events and schedules bots
- **MeetingWorker**: Generates automation outputs after meeting completion

### Privacy & Security

- Bots are clearly identified in meetings as "Social Content Generator Bot"
- Only meetings where you explicitly enable the note taker will have bots
- Transcripts are stored securely and associated with your account
- Bot IDs are tracked to ensure you only access your own meeting data

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
