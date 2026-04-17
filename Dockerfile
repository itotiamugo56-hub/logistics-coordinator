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
    cargo build --release && \
    cp target/release/backend_server /app/backend_server

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binary and data directory
COPY --from=builder /app/backend_server /app/backend_server
COPY --from=builder /app/crates/backend_api/data /app/data

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

CMD ["./backend_server"]