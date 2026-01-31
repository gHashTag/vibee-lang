# Trinity Knowledge Graph Server
# Multi-stage build for minimal image size

FROM alpine:3.19 AS builder

# Install Zig
RUN apk add --no-cache curl xz
RUN curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ -C /opt
ENV PATH="/opt/zig-linux-x86_64-0.13.0:$PATH"

WORKDIR /build
COPY src/vibeec/trinity_kg_server.zig .

# Build static binary
RUN zig build-exe trinity_kg_server.zig -femit-bin=trinity-kg-server -OReleaseSafe

# Runtime stage - minimal image
FROM alpine:3.19

RUN addgroup -g 1001 -S app && \
    adduser -u 1001 -S app -G app

WORKDIR /app
COPY --from=builder /build/trinity-kg-server .
COPY trinity-kg-ui.html .
COPY trinity-stars-ui.html .

# Data directory for persistence
RUN mkdir -p /app/data && chown -R app:app /app

USER app

EXPOSE 8080

CMD ["./trinity-kg-server"]
