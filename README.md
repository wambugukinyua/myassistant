# myassistant

A personal AI assistant powered by the [zeroclaw](https://github.com/zeroclaw-labs/zeroclaw) agent framework, packaged as a Docker container and published to the GitHub Container Registry.

## Features

- 🤖 **zeroclaw** agent runtime with full tool support (web search, screenshot, OCR, PDF extraction, browser automation)
- 💬 **WhatsApp** enabled by default (Cloud API and WhatsApp Web modes)
- 🌐 **Google Chrome** + **scrot** + **Xvfb** for headless browser and screenshot tools
- 📦 Published to **`ghcr.io/wambugukinyua/myassistant`** via GitHub Actions on every push to `main`

---

## Quick start

```bash
# 1. Copy the example env file and fill in your credentials
cp .env.example .env
# Edit .env: set API_KEY, WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID, etc.

# 2. (Optional) copy and customise the zeroclaw config
mkdir -p config
cp config/config.toml.example config/config.toml
# Edit config/config.toml as needed

# 3. Pull and run
docker compose up -d

# 4. Tail the logs (WhatsApp QR code / link appears here on first run)
docker compose logs -f myassistant
```

The zeroclaw gateway listens on **port 42617**.  
Point your WhatsApp webhook at `https://<your-host>:42617/whatsapp`.

---

## Configuration

| Variable | Description |
|---|---|
| `PROVIDER` | LLM provider (`openai`, `anthropic`, `gemini`, `ollama`, …) |
| `ZEROCLAW_MODEL` | Model name (e.g. `gpt-4o`) |
| `API_KEY` | API key for the chosen provider |
| `WHATSAPP_ACCESS_TOKEN` | Meta WhatsApp Cloud API access token |
| `WHATSAPP_PHONE_NUMBER_ID` | WhatsApp Business phone number ID |
| `WHATSAPP_VERIFY_TOKEN` | Webhook verification token (you choose this) |
| `WHATSAPP_APP_SECRET` | *(optional)* HMAC webhook signature verification |

See `.env.example` and `config/config.toml.example` for the full list.

---

## Building locally

```bash
docker build \
  --build-arg ZEROCLAW_VERSION=v0.5.7 \
  --build-arg ZEROCLAW_CARGO_FEATURES="whatsapp-web" \
  -t myassistant:local .
```

---

## GitHub Actions CI/CD

The workflow at `.github/workflows/docker-publish.yml` automatically:

1. Builds the image on every push to `main` / `master` and on tagged releases (`v*.*.*`)
2. Pushes the result to `ghcr.io/wambugukinyua/myassistant` with appropriate tags (`latest`, branch name, semver)
3. Uses **GitHub Actions layer caching** to speed up Rust compilation

Pull requests trigger a build-only run (no push) so you can verify the image builds before merging.

You can also trigger a build manually from the **Actions** tab and specify a different zeroclaw version or extra Cargo features.
