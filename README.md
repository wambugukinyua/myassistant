# myassistant

A personal AI assistant powered by the [zeroclaw](https://github.com/zeroclaw-labs/zeroclaw) agent framework, packaged as a Docker container and published to the GitHub Container Registry.

## Features

- 🤖 **zeroclaw** agent runtime with full tool support (web search, screenshot, OCR, PDF extraction, browser automation)
- 💬 **WhatsApp** enabled by default (Cloud API and WhatsApp Web modes)
- 🌐 **Google Chrome** + **scrot** + **Xvfb** for headless browser and screenshot tools
- 🐍 **Python 3** with a rich set of pre-installed libraries for data analysis, HTTP, AI/LLM SDKs and more (see below)
- 📁 **FileBrowser** — web-based file manager on **port 8080** to browse, upload, download and edit any file inside the container without needing a terminal
- 📦 Published to **`ghcr.io/wambugukinyua/myassistant`** via GitHub Actions on every push to `main`

### Python library suite

| Category | Packages |
|---|---|
| **HTTP & web-scraping** | `requests`, `httpx[http2]`, `aiohttp`, `websocket-client`, `beautifulsoup4`, `lxml` |
| **Data analysis & science** | `numpy`, `pandas`, `scipy`, `matplotlib`, `seaborn`, `statsmodels`, `scikit-learn`, `pyarrow`, `openpyxl`, `tabulate` |
| **AI / LLM SDKs** | `openai`, `anthropic`, `tiktoken` |
| **Config, validation & utilities** | `python-dotenv`, `pydantic`, `rich`, `tqdm`, `tenacity` |
| **Image handling** | `Pillow` |

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

The **FileBrowser** web UI is available on **port 8080** (or the value of `FILEBROWSER_PORT`).  
Open `http://localhost:8080` in your browser to manage files inside the container.  
Default credentials: **admin / admin** — change the password immediately after first login.

---

## File browser

[FileBrowser](https://filebrowser.org/) runs as a second process inside the same container.  
It serves the entire `/zeroclaw-data` directory (workspace, database, config, WhatsApp session) so you can:

- Browse and search files
- Upload / download files
- Create, rename and delete files and folders
- **Edit text files directly in the browser** (syntax highlighting included)

### Credentials

Set `FILEBROWSER_ADMIN_USER` and `FILEBROWSER_ADMIN_PASSWORD` in your `.env` file **before** the first `docker compose up`. These values are written into the FileBrowser database once and are not updated on subsequent restarts.

If you need to change the password after the container has already been initialised:

```bash
docker exec -it myassistant \
  filebrowser users update admin \
    --password '<new-password>' \
    --database /zeroclaw-data/.filebrowser.db
```

### Changing the host port

Set `FILEBROWSER_PORT` in your `.env` file (default is `8080`):

```env
FILEBROWSER_PORT=9090
```

Then recreate the container:

```bash
docker compose up -d --force-recreate
```

> **Security note:** FileBrowser is protected by username/password authentication.  
> Do **not** expose port 8080 to the public internet without first changing the default credentials or placing the service behind a reverse proxy with TLS.

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
| `FILEBROWSER_PORT` | Host port for the FileBrowser web UI (default: `8080`) |
| `FILEBROWSER_ADMIN_USER` | FileBrowser admin username (default: `admin`) — set before first run |
| `FILEBROWSER_ADMIN_PASSWORD` | FileBrowser admin password (default: `admin`) — set before first run |

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
