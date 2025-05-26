# Use the official Elixir image as the base image
FROM elixir:1.18-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Set build ENV
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory and copy the Elixir projects into it
WORKDIR /app
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

# Copy assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

COPY priv priv
COPY assets assets
RUN npm run --prefix ./assets deploy
RUN mix phx.digest

# Copy source code
COPY lib lib
RUN mix compile

# Copy runtime files
COPY rel rel
RUN mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM alpine:3.18 AS app
RUN apk add --no-cache openssl ncurses-libs libstdc++

WORKDIR /app

RUN addgroup -g 1001 -S phoenix && \
    adduser -S phoenix -u 1001

# Copy the release from the build stage
COPY --from=build --chown=phoenix:phoenix /app/_build/prod/rel/social_content_generator ./

USER phoenix

# Expose the port the app runs on
EXPOSE 4000

# Set the default command
CMD ["bin/social_content_generator", "start"] 