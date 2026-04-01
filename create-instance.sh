#!/bin/bash
set -euo pipefail

# ============================================================
#  Create a new RASP user instance
#  Usage: ./create-instance.sh <instance_name> <base_port> [central_ip]
#
#  Port allocation (100-port block per user):
#    FE   = base_port + 0
#    BE   = base_port + 1
#    DB   = base_port + 2
#    DMS  = base_port + 3
# ============================================================

if [ $# -lt 2 ]; then
    echo "Usage: $0 <instance_name> <base_port> [central_ip]"
    echo ""
    echo "Examples:"
    echo "  $0 user1 8000"
    echo "  $0 user2 8100 172.16.202.56"
    exit 1
fi

INSTANCE_NAME="$1"
BASE_PORT="$2"
CENTRAL_IP="${3:-172.16.202.56}"

# ── Calculate ports ─────────────────────────────────────────
PORT_FE=$((BASE_PORT))
PORT_BE=$((BASE_PORT + 1))
PORT_DB=$((BASE_PORT + 2))
PORT_DMS=$((BASE_PORT + 3))
PORT_WORKFLOW=$((BASE_PORT + 4))
PORT_VAULT=$((BASE_PORT + 5))

# ── Detect host IP ─────────────────────────────────────────
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
[ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')
[ -z "$HOST_IP" ] && HOST_IP="127.0.0.1"

# ── Create instance directory ──────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTANCE_DIR="$SCRIPT_DIR/instances/$INSTANCE_NAME"
mkdir -p "$INSTANCE_DIR"

echo "========================================"
echo "  Creating RASP Instance: $INSTANCE_NAME"
echo "========================================"
echo "  Central Server:  $CENTRAL_IP"
echo "  Host IP:         $HOST_IP"
echo "  Frontend Port:   $PORT_FE"
echo "  Backend Port:    $PORT_BE"
echo "  MySQL Port:      $PORT_DB"
echo "  DMS Port:        $PORT_DMS"
echo "  Vault:           $PORT_VAULT"
echo "  Workflow Port:   $PORT_WORKFLOW"
echo "========================================"

# ── Generate .env file ─────────────────────────────────────
ENV_FILE="$INSTANCE_DIR/.env"
cat > "$ENV_FILE" <<EOF
# Auto-generated for instance: $INSTANCE_NAME
# Created: $(date -Iseconds)

PROJECT_NAME=$INSTANCE_NAME

# ── Host IPs ──
HOST_IP=$HOST_IP
CENTRAL_IP=$CENTRAL_IP

# ── Port assignments (base=$BASE_PORT) ──
PORT_FE=$PORT_FE
PORT_BE=$PORT_BE
PORT_DB=$PORT_DB
PORT_DMS=$PORT_DMS
PORT_WORKFLOW=$PORT_WORKFLOW
PORT_VAULT=$((BASE_PORT + 5))

# ── Volume paths (Linux defaults) ──
GENERATED_PATH=/opt/rasp/generated
SOURCE_PROJECT_PATH=/opt/rasp/rasp_backend_source
EOF

echo "✅ Generated: $ENV_FILE"

# ── Symlink compose file into instance dir ─────────────────
COMPOSE_SOURCE="$SCRIPT_DIR/docker-compose.local.yml"
COMPOSE_LINK="$INSTANCE_DIR/docker-compose.local.yml"
if [ ! -f "$COMPOSE_LINK" ]; then
    ln -sf "$COMPOSE_SOURCE" "$COMPOSE_LINK"
fi

# ── Start the instance ─────────────────────────────────────
echo ""
echo "Starting instance '$INSTANCE_NAME' ..."

if docker compose version >/dev/null 2>&1; then
    docker compose -p "$INSTANCE_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_SOURCE" up -d
else
    docker-compose -p "$INSTANCE_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_SOURCE" up -d
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo -e "\033[1;32m✅ Instance '$INSTANCE_NAME' is running!\033[0m"
    echo "========================================"
    echo "  Frontend:   http://$HOST_IP:$PORT_FE"
    echo "  Backend:    http://$HOST_IP:$PORT_BE"
    echo "  MySQL:      $HOST_IP:$PORT_DB"
    echo "  DMS:        http://$HOST_IP:$PORT_DMS"
    echo "  Vault:      http://$HOST_IP:$PORT_VAULT"
    echo "  Workflow:   http://$HOST_IP:$PORT_WORKFLOW"
    echo "  RBAC (central):  http://$CENTRAL_IP:9082"
    echo "  Collab (central): http://$CENTRAL_IP:8088"
    echo "========================================"
else
    echo -e "\033[1;31m❌ Failed to start instance '$INSTANCE_NAME'.\033[0m"
    exit 1
fi
