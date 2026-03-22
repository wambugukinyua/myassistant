# =============================================================================
# myassistant — powered by the zeroclaw agent framework
# Multi-stage build targeting GitHub Container Registry (ghcr.io)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build zeroclaw from source with WhatsApp-web support
# -----------------------------------------------------------------------------
FROM rust:1.87-slim AS builder

WORKDIR /zeroclaw

# Install build-time system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        pkg-config \
        libssl-dev \
        git \
    && rm -rf /var/lib/apt/lists/*

# Pin to a stable zeroclaw release; override with --build-arg ZEROCLAW_VERSION=...
ARG ZEROCLAW_VERSION=v0.5.7

RUN git clone --depth 1 --branch "${ZEROCLAW_VERSION}" \
        https://github.com/zeroclaw-labs/zeroclaw.git .

# whatsapp-web is compiled in by default; add extra Cargo features via build-arg
ARG ZEROCLAW_CARGO_FEATURES="whatsapp-web"

RUN cargo build --release --features "${ZEROCLAW_CARGO_FEATURES}"

# Shrink the binary
RUN strip target/release/zeroclaw

# -----------------------------------------------------------------------------
# Stage 2: Runtime image with all tools zeroclaw needs
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

# ---- Base utilities & zeroclaw tool dependencies ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        # TLS / networking
        ca-certificates \
        curl \
        wget \
        gnupg \
        # Screenshot & display capture (used by zeroclaw screenshot / OCR tools)
        scrot \
        imagemagick \
        xvfb \
        x11-apps \
        # OCR support
        tesseract-ocr \
        # PDF extraction
        poppler-utils \
        # Fonts (needed by Chrome & image rendering)
        fonts-liberation \
        fonts-noto \
        # Chrome/Chromium runtime libraries
        libnspr4 \
        libnss3 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libxkbcommon0 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libxtst6 \
        libasound2 \
        # Process utilities
        procps \
    && rm -rf /var/lib/apt/lists/*

# ---- Google Chrome (stable) —— required for browser-automation tool ---------
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
             https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# ---- Copy zeroclaw binary from builder --------------------------------------
COPY --from=builder /zeroclaw/target/release/zeroclaw /usr/local/bin/zeroclaw

# ---- Copy default config (users can mount their own at /zeroclaw-data/.zeroclaw/config.toml)
COPY config/config.toml.example /etc/zeroclaw/config.toml.example

# ---- Runtime user & directories ---------------------------------------------
RUN useradd --create-home --uid 1000 --shell /bin/bash zeroclaw \
    && mkdir -p /zeroclaw-data/workspace /zeroclaw-data/.zeroclaw \
    && chown -R zeroclaw:zeroclaw /zeroclaw-data

USER zeroclaw
WORKDIR /zeroclaw-data

# ---- Environment variables --------------------------------------------------
ENV LANG=C.UTF-8
ENV ZEROCLAW_WORKSPACE=/zeroclaw-data/workspace
ENV ZEROCLAW_GATEWAY_PORT=42617
# Enable WhatsApp as the default active channel
ENV ZEROCLAW_CHANNELS=whatsapp
# Uncomment and set these at runtime (or via docker-compose / CI secrets):
# ENV PROVIDER=openai
# ENV ZEROCLAW_MODEL=gpt-4o
# ENV API_KEY=sk-...

# ---- Expose the zeroclaw gateway port ---------------------------------------
EXPOSE 42617

# ---- Health check -----------------------------------------------------------
# curl is available in this image; hits the gateway's HTTP root to confirm
# the process is alive and accepting connections on port 42617.
HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:42617/ || exit 1

# ---- Default command --------------------------------------------------------
CMD ["zeroclaw", "gateway"]
