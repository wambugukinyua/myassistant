# =============================================================================
# myassistant — powered by the zeroclaw agent framework
# Multi-stage build targeting GitHub Container Registry (ghcr.io)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build zeroclaw from source with WhatsApp-web support
# -----------------------------------------------------------------------------
FROM rust:1.89-slim AS builder

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
FROM debian:trixie-slim AS runtime

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
        libasound2t64 \
        # Process utilities
        procps \
        # Text editor
        nano \
        # Allow the runtime user to install extra packages
        sudo \
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

# ---- Python 3 runtime + build tools ----------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        # needed to compile some Python C-extensions (e.g. numpy, lxml)
        build-essential \
        libffi-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# ---- Python libraries for the AI agent --------------------------------------
# Versions are pinned in requirements.txt for reproducible builds.
# Using --break-system-packages is intentional: this is a container image and
# we want packages available system-wide without a virtual-env wrapper.
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

# ---- FileBrowser (web-based file manager on port 8080) ----------------------
# Download a pinned release directly from GitHub — avoids piping to bash.
# Override the version at build time with --build-arg FILEBROWSER_VERSION=...
ARG FILEBROWSER_VERSION=v2.32.0
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64) FB_ARCH="linux-amd64" ;; \
        arm64) FB_ARCH="linux-arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/filebrowser.tar.gz \
        "https://github.com/filebrowser/filebrowser/releases/download/${FILEBROWSER_VERSION}/${FB_ARCH}-filebrowser.tar.gz"; \
    tar -xzf /tmp/filebrowser.tar.gz -C /usr/local/bin filebrowser; \
    chmod +x /usr/local/bin/filebrowser; \
    rm /tmp/filebrowser.tar.gz

# ---- Copy zeroclaw binary from builder --------------------------------------
COPY --from=builder /zeroclaw/target/release/zeroclaw /usr/local/bin/zeroclaw

# ---- Copy default config (users can mount their own at /zeroclaw-data/.zeroclaw/config.toml)
COPY config/config.toml.example /etc/zeroclaw/config.toml.example

# ---- Runtime user & directories ---------------------------------------------
RUN useradd --create-home --uid 1000 --shell /bin/bash zeroclaw \
    && mkdir -p /zeroclaw-data/workspace /zeroclaw-data/.zeroclaw \
    && chown -R zeroclaw:zeroclaw /zeroclaw-data \
    && echo "zeroclaw ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt" \
        > /etc/sudoers.d/zeroclaw-apt \
    && chmod 0440 /etc/sudoers.d/zeroclaw-apt

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

# ---- Expose ports -----------------------------------------------------------
# 42617 — zeroclaw gateway / webhook receiver
# 8080  — FileBrowser web UI (browse & edit files in /zeroclaw-data)
EXPOSE 42617
EXPOSE 8080

# ---- Health check -----------------------------------------------------------
# curl is available in this image; hits the gateway's HTTP root to confirm
# the process is alive and accepting connections on port 42617.
HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:42617/ || exit 1

# ---- Default command --------------------------------------------------------
# NOTE: docker-compose overrides this with an entrypoint that also starts
# Xvfb and FileBrowser.  The CMD here is used only when the image is run
# directly (e.g. docker run …).
CMD ["zeroclaw", "daemon"]
