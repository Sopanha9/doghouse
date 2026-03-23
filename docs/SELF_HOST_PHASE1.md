# Self-Host Phase 1 (Practical Baseline)

This phase gives you a reproducible local self-host baseline for the backend and voice services.
It avoids stale `kofta` references and uses a dedicated compose override.

## 1. Create local env files

From repository root:

```bash
cp kousa.env.example kousa.env
cp shawarma.env.example shawarma.env
cp pg.env.example pg.env
cp rabbit.env.example rabbit.env
cp kibbeh/.env.example kibbeh/.env.local
```

Then edit these values before startup:

- `kousa.env`: all OAuth credentials and secret values
- `shawarma.env`: set `WEBRTC_LISTEN_IP` and `A_IP` for your network
- `kibbeh/.env.local`: set `NEXT_PUBLIC_API_BASE_URL=http://localhost:4001`

## 2. Start infrastructure + services with Docker

```bash
docker compose -f docker-compose.yml -f docker-compose.selfhost.yml up -d --build
```

Expected exposed services:

- API: `http://localhost:4001`
- Adminer: `http://localhost:8080`
- RabbitMQ UI: `http://localhost:15672`

## 3. Start frontend (host machine)

In a separate terminal:

```bash
cd kibbeh
yarn
yarn dev
```

Open: `http://localhost:3000`

## 4. Health checks

```bash
docker compose -f docker-compose.yml -f docker-compose.selfhost.yml ps
docker compose -f docker-compose.yml -f docker-compose.selfhost.yml logs -f kousa shawarma
```

## 5. Production notes

- Put reverse proxy + TLS in front of web and API.
- Set `WEB_URL` and `API_URL` in `kousa.env` to real domains.
- Open UDP range `40000-49999` for mediasoup.
- Set `A_IP` in `shawarma.env` to the public IP users must reach.

## 6. Stop everything

```bash
docker compose -f docker-compose.yml -f docker-compose.selfhost.yml down
```
