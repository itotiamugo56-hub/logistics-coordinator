# Dockerfile - Zero-Trust Logistics Backend
FROM rust:1.82-slim-bookworm AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy entire workspace
COPY . .

# Build the backend binary
RUN cd crates/backend_api && \
    cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary maintaining the expected path structure
COPY --from=builder /app/target/release/backend_server /app/target/release/backend_server
COPY --from=builder /app/crates/backend_api/data /app/data

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ./target/release/backend_server --health-check || exit 1

CMD ["./target/release/backend_server"]