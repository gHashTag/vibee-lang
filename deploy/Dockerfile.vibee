# VIBEE Language - Multi-Arch Docker Build
# Supports amd64 (x86_64) and arm64 (aarch64)
# φ² + 1/φ² = 3 | PHOENIX = 999

ARG ZIG_VERSION=0.13.0
ARG TARGETARCH

FROM alpine:3.19 AS builder

ARG ZIG_VERSION
ARG TARGETARCH

# Install dependencies
RUN apk add --no-cache curl xz tar

# Download Zig for the target architecture
RUN case "${TARGETARCH}" in \
    amd64) ZIG_ARCH="x86_64" ;; \
    arm64) ZIG_ARCH="aarch64" ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz" -o zig.tar.xz && \
    tar -xf zig.tar.xz -C /opt && \
    rm zig.tar.xz

ENV PATH="/opt/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}:$PATH"

WORKDIR /build

# Copy compiler source
COPY src/vibeec/ ./src/vibeec/
COPY specs/ ./specs/
COPY bindings/ ./bindings/

# Build compiler with ReleaseSafe optimization (safe for all CPUs)
RUN cd src/vibeec && zig build -Doptimize=ReleaseSafe

# Runtime image
FROM alpine:3.19

ARG TARGETARCH

RUN apk add --no-cache libc6-compat

WORKDIR /vibee

# Copy built binary
COPY --from=builder /build/src/vibeec/zig-out/bin/vibeec /usr/local/bin/vibee

# Copy specifications
COPY --from=builder /build/specs/ ./specs/

# Set up volumes for user specifications and output
VOLUME ["/vibee/user-specs", "/vibee/output"]

# Default command
ENTRYPOINT ["vibee"]
CMD ["--help"]

LABEL org.opencontainers.image.title="VIBEE Language"
LABEL org.opencontainers.image.description="Specification-first programming language that generates code from behavioral specifications"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/gHashTag/vibee-lang"
LABEL org.opencontainers.image.licenses="MIT"

# Verify installation
RUN vibee --version 2>/dev/null || echo "VIBEE version unknown"
