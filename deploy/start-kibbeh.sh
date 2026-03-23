#!/usr/bin/env bash
set -euo pipefail

# Try common Node install locations first, then fall back to PATH.
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

if ! command -v node >/dev/null 2>&1; then
  echo "node was not found in PATH"
  exit 1
fi

if ! command -v yarn >/dev/null 2>&1; then
  echo "yarn was not found in PATH"
  exit 1
fi

export NODE_OPTIONS="${NODE_OPTIONS:---openssl-legacy-provider}"

# Build before serving so the process can run behind a reverse proxy.
yarn install --immutable
yarn build
exec yarn start -p 3000
