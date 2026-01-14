FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.13.0
RUN wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz && \
    tar -xf zig-linux-x86_64-0.13.0.tar.xz && \
    mv zig-linux-x86_64-0.13.0 /usr/local/zig && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig && \
    rm zig-linux-x86_64-0.13.0.tar.xz

# Install Erlang/OTP 25 and rebar3
RUN apt-get update && \
    apt-get install -y erlang rebar3 && \
    rm -rf /var/lib/apt/lists/*

# Install Gleam v1.14.0 (direct binary download)
RUN mkdir -p /usr/local/bin && \
    wget https://github.com/gleam-lang/gleam/releases/download/v1.14.0/gleam-v1.14.0-x86_64-unknown-linux-musl.tar.gz && \
    tar -xzf gleam-v1.14.0-x86_64-unknown-linux-musl.tar.gz && \
    mv gleam /usr/local/bin/ && \
    chmod +x /usr/local/bin/gleam && \
    rm gleam-v1.14.0-x86_64-unknown-linux-musl.tar.gz

# Install flyctl
RUN curl -L https://fly.io/install.sh | sh

# Add flyctl to PATH
ENV FLYCTL_INSTALL="/root/.fly"
ENV PATH="$FLYCTL_INSTALL/bin:$PATH"

# Verify installations
RUN gleam --version && erl -version && rebar3 version && zig version
