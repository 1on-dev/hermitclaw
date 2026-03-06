# Deploying HermitClaw to Railway

## Prerequisites

- A [Railway](https://railway.app) account
- An OpenAI API key (or another supported provider)
- Docker installed locally (to build and push the image)

---

## Environment Variables

Set these in Railway under **Service → Variables**:

| Variable | Required | Description |
|---|---|---|
| `OPENAI_API_KEY` | Yes | Your OpenAI API key |
| `HERMITCLAW_NAME` | No | Crab name (default: `Lhek`) |
| `HERMITCLAW_MODEL` | No | Model to use (default: `gpt-4.1`) |
| `HERMITCLAW_PROVIDER` | No | `openai` \| `openrouter` \| `custom` (default: `openai`) |
| `HERMITCLAW_SECRET` | No | API guard secret — see [API Guard](#api-guard) below |
| `HERMIT_FOLDER` | No | Path where crab boxes live (default: `/data/hermit`) |
| `OPENROUTER_API_KEY` | No | Required if using OpenRouter |
| `OLLAMA_API_KEY` | No | Required for Ollama cloud web search |

---

## Deploy Steps

### 1. Build and push the Docker image

```bash
# From the repo root
docker build -t your-dockerhub-username/hermitclaw:latest .
docker push your-dockerhub-username/hermitclaw:latest
```

Or use Railway's GitHub integration to build on push — point it at the `Dockerfile` in the repo root.

### 2. Create a new Railway service

1. New Project → **Deploy from Docker image** (or connect your GitHub repo)
2. Set the image to `your-dockerhub-username/hermitclaw:latest`
3. Railway will detect `PORT=8000` from the Dockerfile automatically

### 3. Add a volume for persistence

The crab's identity, memories, and files live in `/data/hermit`. Without a persistent volume, everything resets on redeploy.

1. In Railway: **Service → Volumes → Add Volume**
2. Mount path: `/data/hermit`

### 4. Set environment variables

Add at minimum `OPENAI_API_KEY` under **Service → Variables**.

### 5. Deploy

Trigger a deploy. On first boot, the crab auto-creates itself using `HERMITCLAW_NAME` and system entropy — no interactive setup needed.

---

## Accessing the UI

Once deployed, Railway gives you a public URL (e.g. `https://hermitclaw-production.up.railway.app`).

Open it in a browser. You'll see:
- **Left pane** — the crab's pixel-art room. Watch it move between its desk, bookshelf, window, and bed.
- **Right pane** — the live thought feed. Every think cycle, tool call, and reflection appears here in real time.

---

## Interacting with the Crab

### Sending a message

Type in the input box at the bottom and press **Send** (or Enter).

The crab hears it as *"a voice from outside the room"* on its next think cycle. It may choose to respond (using the `respond` tool) or keep working. If it responds, you have **15 seconds** to reply — the countdown shows in the input bar. After the timeout, it returns to its work.

### Focus mode

Click the **Focus** button (turns orange when active). In focus mode the crab ignores its normal autonomous moods and concentrates entirely on whatever you've given it — useful when you've sent it a task or dropped in a file.

Click Focus again to turn it off.

### Dropping files in

Files can't be uploaded through the UI directly. On Railway, use the Railway CLI or volume mount to put files into the crab's box:

```bash
# Using Railway CLI
railway run cp myfile.pdf /data/hermit/lhek_box/myfile.pdf
```

The crab checks for new files each think cycle and alerts when it finds one, then reads and responds to it.

Supported types: `.txt`, `.md`, `.py`, `.json`, `.csv`, `.yaml`, `.pdf`, `.png`, `.jpg`, `.gif`, `.webp`

### Viewing the crab's files

Use the REST API to browse files the crab has created:

```bash
# List all files in the box
curl https://your-app.up.railway.app/api/files

# Read a specific file
curl https://your-app.up.railway.app/api/files/research/mycology-report.md
```

---

## API Reference

All endpoints are under the Railway public URL.

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/crabs` | List all running crabs |
| `POST` | `/api/crabs` | Create a new crab at runtime |
| `GET` | `/api/status` | Current state, thought count, focus mode |
| `GET` | `/api/identity` | Crab name, genome, traits, birthday |
| `GET` | `/api/events` | Recent event log |
| `GET` | `/api/raw` | Raw LLM call history |
| `POST` | `/api/message` | Send a message to the crab |
| `POST` | `/api/focus-mode` | Toggle focus mode |
| `GET` | `/api/files` | List files in the crab's box |
| `GET` | `/api/files/{path}` | Read a file from the crab's box |
| `WS` | `/ws/{crab_id}` | WebSocket — live events |

### Create a crab via API

```bash
curl -X POST https://your-app.up.railway.app/api/crabs \
  -H "Content-Type: application/json" \
  -d '{"name": "Pepper"}'
```

### Send a message via API

```bash
curl -X POST https://your-app.up.railway.app/api/message \
  -H "Content-Type: application/json" \
  -d '{"text": "What are you working on?"}'
```

---

## API Guard

Setting `HERMITCLAW_SECRET` requires a `X-Secret` header on all `/api/*` requests and a `?secret=` query param on WebSocket connections.

**Important:** the bundled frontend UI does **not** send this header, so enabling the secret will break the browser UI. The guard is useful for protecting direct API access (scripts, curl, external integrations), not for restricting browser access to the UI.

If you need to restrict who can open the UI at all, Railway's built-in [Private Networking](https://docs.railway.app/reference/private-networking) or a reverse proxy with HTTP basic auth is a better fit.

When the secret is set, API calls look like:

```bash
curl https://your-app.up.railway.app/api/status \
  -H "X-Secret: your-secret-here"
```

WebSocket with secret:
```
wss://your-app.up.railway.app/ws/lhek?secret=your-secret-here
```

---

## Troubleshooting

**Crab resets on every redeploy**
Make sure the Railway volume is mounted at `/data/hermit` and `HERMIT_FOLDER` is set to `/data/hermit` (it is by default in the Dockerfile).

**"No module named hermitclaw"**
The Dockerfile runs `uv sync` before copying the full source. If you changed `pyproject.toml`, rebuild the image from scratch (`docker build --no-cache ...`).

**Frontend loads but shows nothing / spins forever**
Check Railway logs for startup errors — usually a missing `OPENAI_API_KEY` or a failed API call on first boot.

**Crab isn't thinking**
Check `/api/status` — if `state` is `idle` and `thought_count` is not incrementing, the thinking loop may have crashed. Check logs for `brain.py` errors, usually an invalid API key or model name.

**Out of credits**
The crab runs continuously. Set `thinking_pace_seconds` to a higher value (e.g. `60`) in `config.yaml` to slow it down and reduce API usage.
