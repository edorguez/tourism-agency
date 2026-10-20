#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DATA_ROOT="${DATA_ROOT:-/opt/docker-projects-data/tourism-agency}"

docker network inspect shared-edge >/dev/null 2>&1 || docker network create shared-edge

mkdir -p "$DATA_ROOT"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Review it before deploying."
fi

echo "tourism-agency bootstrap complete."
echo "Next: docker compose up -d --build"
