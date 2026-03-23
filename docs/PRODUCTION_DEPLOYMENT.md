# Production Deployment (Domain + TLS)

This guide assumes you already validated local self-hosting from `docs/SELF_HOST_PHASE1.md`.

## 1. Requirements

- Linux VPS with public IPv4.
- DNS control for:
  - `your-domain.com` (frontend)
  - `api.your-domain.com` (API)
- Docker + Docker Compose installed.
- Node 18 runtime available for kibbeh process.

## 1.1 Hosting choice (Railway + Vercel)

- **Recommended for this stack:** run `kousa + shawarma + postgres + rabbitmq` on a VPS (Hetzner, DigitalOcean, AWS EC2, Fly VM).
- **Why:** `shawarma` (mediasoup) needs public UDP range `40000-49999`, which is generally not suitable on serverless/frontend platforms.
- **Vercel:** good option for frontend (`kibbeh`) only.
- **Railway:** can be used for app containers and databases, but voice UDP requirements are the blocker for a pure Railway deployment.

Practical split if you keep Vercel/Railway:

1. Vercel -> `kibbeh` frontend
2. VPS -> `shawarma` + `kousa` (+ optionally Postgres/RabbitMQ)
3. Point Vercel frontend env to VPS API domain

## 2. DNS

Create A records:

- `your-domain.com` -> `SERVER_PUBLIC_IP`
- `api.your-domain.com` -> `SERVER_PUBLIC_IP`

## 3. Environment values

Copy and fill files in repo root:

```bash
cp kousa.env.example kousa.env
cp shawarma.env.example shawarma.env
cp pg.env.example pg.env
cp rabbit.env.example rabbit.env
cp kibbeh/.env.example kibbeh/.env.local
```

Set at minimum:

- `kousa.env`
  - `WEB_URL=https://your-domain.com`
  - `API_URL=https://api.your-domain.com`
  - real OAuth credentials and callback-compatible settings
- `shawarma.env`
  - `WEBRTC_LISTEN_IP=0.0.0.0`
  - `A_IP=SERVER_PUBLIC_IP`
- `kibbeh/.env.local`
  - `NEXT_PUBLIC_API_BASE_URL=https://api.your-domain.com`
  - `NEXT_PUBLIC_BASE_URL=https://your-domain.com`

## 4. Start backend + voice

From repo root:

```bash
docker compose -f deploy/docker-compose.internet.yml up -d --build
```

This profile keeps API/RabbitMQ ports local-only except UDP media range `40000-49999`.

## 5. Start frontend process

From repo root:

```bash
cd kibbeh
bash ../deploy/start-kibbeh.sh
```

The startup wrapper auto-detects common Node locations and verifies `node` + `yarn` are available.

## 6. Reverse proxy (choose one)

### Option A: Caddy (recommended)

1. Copy `deploy/Caddyfile.example` to your Caddy config.
2. Replace `your-domain.com` and `api.your-domain.com`.
3. Reload Caddy.

### Option B: Nginx

1. Copy `deploy/nginx.dogehouse.conf.example` to your site config.
2. Replace domain names.
3. Enable site and reload Nginx.
4. Add TLS with certbot or your existing certificate setup.

## 7. Firewall

Open these ports publicly:

- `80/tcp` and `443/tcp`
- `40000-49999/udp` (WebRTC media)

Keep closed to public internet:

- `5672/tcp`, `15672/tcp`, `5432/tcp`, `4001/tcp`

## 8. Verify

```bash
bash deploy/smoke-test.sh your-domain.com api.your-domain.com
```

Also test with two devices/networks joining the same room for real audio validation.

## 9. One-command deployment

1. Install the systemd unit:

```bash
sudo cp deploy/kibbeh.service /etc/systemd/system/kibbeh.service
sudo systemctl daemon-reload
```

2. Run end-to-end deploy:

```bash
bash deploy/deploy.sh your-domain.com api.your-domain.com
```

Optional modes:

```bash
# Backend/voice only (skip frontend build/start)
DEPLOY_FRONTEND=0 bash deploy/deploy.sh your-domain.com api.your-domain.com
```

The script will:

- build and start backend/voice containers
- install dependencies and build `kebab` + `kibbeh`
- start/restart the `kibbeh` service
- run smoke tests against domain and local endpoints

It also auto-detects common Node locations, so manual PATH edits are usually unnecessary.

## 10. Preflight checks

Run explicit validation before deployment:

```bash
bash deploy/preflight.sh
```

This checks:

- required env files exist
- required commands are installed
- critical env values are not placeholder defaults
- compose file is renderable
