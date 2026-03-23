#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-your-domain.com}"
API_DOMAIN="${2:-api.your-domain.com}"

check() {
  local name="$1"
  local url="$2"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"
  printf '%-18s %s %s\n' "$name" "$code" "$url"
}

echo "Service smoke test"
echo "-------------------"
check "frontend" "https://${DOMAIN}"
check "api" "https://${API_DOMAIN}"
check "api-local" "http://127.0.0.1:4001"
check "rabbitmq-ui" "http://127.0.0.1:15672"

echo
echo "Container status"
docker compose -f deploy/docker-compose.internet.yml ps
