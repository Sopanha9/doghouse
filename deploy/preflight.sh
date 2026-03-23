#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_FRONTEND="${DEPLOY_FRONTEND:-1}"

fail() {
  echo "[preflight] ERROR: $1"
  exit 1
}

require_file() {
  local f="$1"
  [[ -f "$ROOT_DIR/$f" ]] || fail "Missing file: $f"
}

require_non_placeholder() {
  local file="$1"
  local key="$2"
  local value
  value="$(grep -E "^${key}=" "$ROOT_DIR/$file" | head -n1 | cut -d'=' -f2- || true)"
  [[ -n "$value" ]] || fail "$file is missing ${key}"
  case "$value" in
    replace-me|replace-with-*|""|http://localhost:*|https://localhost:*|SERVER_PUBLIC_IP)
      fail "$file has placeholder value for ${key}: $value"
      ;;
  esac
}

echo "[preflight] checking required files"
require_file "kousa.env"
require_file "shawarma.env"
require_file "pg.env"
require_file "rabbit.env"
require_file "kibbeh/.env.local"
require_file "deploy/docker-compose.internet.yml"

echo "[preflight] checking required commands"
command -v docker >/dev/null 2>&1 || fail "docker command not found"
command -v curl >/dev/null 2>&1 || fail "curl command not found"

if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
  command -v node >/dev/null 2>&1 || fail "node command not found"
  command -v yarn >/dev/null 2>&1 || fail "yarn command not found"
fi

echo "[preflight] checking non-placeholder env values"
require_non_placeholder "kousa.env" "WEB_URL"
require_non_placeholder "kousa.env" "API_URL"
require_non_placeholder "kousa.env" "SECRET_KEY_BASE"
require_non_placeholder "kousa.env" "ACCESS_TOKEN_SECRET"
require_non_placeholder "kousa.env" "REFRESH_TOKEN_SECRET"
require_non_placeholder "kousa.env" "GITHUB_CLIENT_ID"
require_non_placeholder "kousa.env" "GITHUB_CLIENT_SECRET"
require_non_placeholder "kousa.env" "TWITTER_API_KEY"
require_non_placeholder "kousa.env" "TWITTER_SECRET_KEY"
require_non_placeholder "kousa.env" "TWITTER_BEARER_TOKEN"
require_non_placeholder "kousa.env" "DISCORD_CLIENT_ID"
require_non_placeholder "kousa.env" "DISCORD_CLIENT_SECRET"
require_non_placeholder "kousa.env" "GOOGLE_CLIENT_ID"
require_non_placeholder "kousa.env" "GOOGLE_CLIENT_SECRET"

require_non_placeholder "shawarma.env" "WEBRTC_LISTEN_IP"
require_non_placeholder "shawarma.env" "A_IP"

echo "[preflight] validating compose rendering"
(
  cd "$ROOT_DIR"
  docker compose -f deploy/docker-compose.internet.yml config >/dev/null
)

echo "[preflight] OK"
