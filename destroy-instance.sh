#!/bin/bash
set -euo pipefail

# ============================================================
#  Destroy a RASP user instance
#  Usage: ./destroy-instance.sh <instance_name> [--keep-data]
# ============================================================

if [ $# -lt 1 ]; then
    echo "Usage: $0 <instance_name> [--keep-data]"
    exit 1
fi

INSTANCE_NAME="$1"
KEEP_DATA="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTANCE_DIR="$SCRIPT_DIR/instances/$INSTANCE_NAME"
COMPOSE_SOURCE="$SCRIPT_DIR/docker-compose.local.yml"
ENV_FILE="$INSTANCE_DIR/.env"

echo "========================================"
echo "  Destroying RASP Instance: $INSTANCE_NAME"
echo "========================================"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  No .env found at $ENV_FILE"
    echo "   Attempting to stop by project name only ..."
fi

# ── Stop and remove containers ─────────────────────────────
if [ "$KEEP_DATA" = "--keep-data" ]; then
    echo "Stopping containers (keeping volumes) ..."
    if docker compose version >/dev/null 2>&1; then
        docker compose -p "$INSTANCE_NAME" -f "$COMPOSE_SOURCE" down
    else
        docker-compose -p "$INSTANCE_NAME" -f "$COMPOSE_SOURCE" down
    fi
else
    echo "Stopping containers and removing volumes ..."
    if docker compose version >/dev/null 2>&1; then
        docker compose -p "$INSTANCE_NAME" -f "$COMPOSE_SOURCE" down -v
    else
        docker-compose -p "$INSTANCE_NAME" -f "$COMPOSE_SOURCE" down -v
    fi
fi

# ── Clean up instance directory ────────────────────────────
if [ -d "$INSTANCE_DIR" ]; then
    rm -rf "$INSTANCE_DIR"
    echo "Removed instance directory: $INSTANCE_DIR"
fi

echo ""
echo -e "\033[1;32m✅ Instance '$INSTANCE_NAME' destroyed.\033[0m"
