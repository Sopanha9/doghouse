#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
API_DOMAIN="${2:-}"

if [[ -z "$DOMAIN" || -z "$API_DOMAIN" ]]; then
  echo "Usage: bash deploy/deploy.sh <domain> <api-domain>"
  echo "Example: bash deploy/deploy.sh doge.example.com api.doge.example.com"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
USE_SYSTEMD="${USE_SYSTEMD:-1}"
SERVICE_NAME="${SERVICE_NAME:-kibbeh}"
DEPLOY_FRONTEND="${DEPLOY_FRONTEND:-1}"

# Auto-detect common Node install locations.
for candidate in \
  /opt/homebrew/opt/node@18/bin \
  /usr/local/opt/node@18/bin \
  /usr/local/bin \
  /usr/bin
do
  if [[ -x "${candidate}/node" ]]; then
    export PATH="${candidate}:$PATH"
    break
  fi
done

if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    echo "node was not found in PATH"
    exit 1
  fi

  if ! command -v yarn >/dev/null 2>&1; then
    echo "yarn was not found in PATH"
    exit 1
  fi
fi

export NODE_OPTIONS="--openssl-legacy-provider"

echo "[0/6] Running preflight checks"
cd "$ROOT_DIR"
bash deploy/preflight.sh

echo "[1/6] Starting backend and voice containers"
cd "$ROOT_DIR"
docker compose -f deploy/docker-compose.internet.yml up -d --build

if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
  echo "[2/6] Installing monorepo dependencies"
  yarn

  echo "[3/6] Building required workspaces"
  yarn workspace @dogehouse/kebab build
  yarn workspace @dogehouse/kibbeh build

  echo "[4/6] Starting/restarting frontend"
  if [[ "$USE_SYSTEMD" == "1" ]] && command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
      sudo systemctl daemon-reload
      sudo systemctl enable --now "${SERVICE_NAME}"
      sudo systemctl restart "${SERVICE_NAME}"
    else
      echo "Systemd service ${SERVICE_NAME}.service not found."
      echo "Install deploy/kibbeh.service to /etc/systemd/system/${SERVICE_NAME}.service first."
      exit 1
    fi
  else
    echo "USE_SYSTEMD disabled or systemctl not available; starting fallback process."
    pkill -f "next start -p 3000" || true
    nohup yarn workspace @dogehouse/kibbeh start -p 3000 > "$ROOT_DIR/.docker/kibbeh.log" 2>&1 &
  fi
else
  echo "[2-4/6] Skipping frontend build/start (DEPLOY_FRONTEND=0)"
fi

echo "[5/6] Running smoke test"
bash deploy/smoke-test.sh "$DOMAIN" "$API_DOMAIN"

echo "[6/6] Deployment summary complete"
echo "Deployment completed."
