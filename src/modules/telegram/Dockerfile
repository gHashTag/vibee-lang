FROM ghcr.io/gleam-lang/gleam:v1.13.0-erlang-alpine

WORKDIR /app

# Copy gleam project files
COPY gleam/gleam.toml gleam/
COPY gleam/manifest.toml gleam/

# Copy honeycomb to gleam/src/
COPY honeycomb gleam/src/honeycomb/

WORKDIR /app/gleam

# Build
RUN gleam build

# Environment
ENV TELEGRAM_BOT_TOKEN=""

# Run
CMD ["gleam", "run", "-m", "honeycomb/telegram_bot/run"]
