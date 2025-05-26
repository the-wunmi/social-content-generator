# Use the official Elixir image as the base image  
FROM elixir:1.18-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base npm git python3 curl

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

# Copy assets first and install npm dependencies
COPY assets/package.json ./assets/
RUN cd assets && npm install --production=false

# Copy all source files
COPY priv priv
COPY assets assets
COPY lib lib

# Build assets manually to avoid esbuild download issues
RUN cd assets && \
    mkdir -p ../priv/static/assets && \
    npx esbuild js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* && \
    npx tailwindcss --config=tailwind.config.js --input=css/app.css --output=../priv/static/assets/app.css --minify

# Run Phoenix digest to add cache-busting hashes
RUN mix phx.digest

# Compile the application
RUN mix compile

# Source code already copied above

# Build release
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