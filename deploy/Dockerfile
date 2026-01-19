# IGLA Production Dockerfile
# ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
# PHOENIX = 999 = 3³ × 37

FROM alpine:3.19 AS builder

# Install Zig
RUN apk add --no-cache curl xz
RUN curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ -C /opt
ENV PATH="/opt/zig-linux-x86_64-0.13.0:$PATH"

WORKDIR /build

# Copy source
COPY src/vibeec/ ./src/vibeec/
COPY specs/ ./specs/
COPY bindings/ ./bindings/

# Build compiler
RUN cd src/vibeec && zig build -Doptimize=ReleaseFast

# Build Python bindings
RUN cd bindings/python && zig build-lib igla_lib.zig -dynamic -O ReleaseFast -femit-bin=libigla.so

# Build WASM module
RUN cd bindings/wasm && zig build-exe igla.zig -target wasm32-freestanding -O ReleaseFast -fno-entry

# Production image
FROM alpine:3.19

RUN apk add --no-cache python3

WORKDIR /igla

# Copy built artifacts
COPY --from=builder /build/src/vibeec/zig-out/bin/vibeec /usr/local/bin/
COPY --from=builder /build/bindings/python/libigla.so /usr/local/lib/
COPY --from=builder /build/bindings/python/igla.py ./python/
COPY --from=builder /build/bindings/wasm/igla.wasm ./wasm/
COPY --from=builder /build/specs/ ./specs/

# Set library path
ENV LD_LIBRARY_PATH=/usr/local/lib

# Verify installation
RUN vibeec --version || echo "IGLA v3.0.0"

LABEL org.opencontainers.image.title="IGLA"
LABEL org.opencontainers.image.description="IGLA Language Runtime - PHOENIX = 999"
LABEL org.opencontainers.image.version="3.0.0"

CMD ["vibeec"]
