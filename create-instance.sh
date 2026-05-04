#!/bin/bash
set -euo pipefail

# ============================================================
#  Create a new RASP user instance
#  Usage: ./create-instance.sh <instance_name> <base_port> [central_ip]
#
#  Port allocation (100-port block per user):
#    FE       = base_port + 0   (Frontend)
#    BE       = base_port + 1   (Backend / RASP API)
#    DB       = base_port + 2   (Local MySQL)
#    DMS      = base_port + 3   (Document Management)
#    WORKFLOW = base_port + 4   (Workflow engine)
#    VAULT    = base_port + 5   (Secret vault)
#
#  Shared central services (not per-instance):
#    Collab Server   → <central_ip>:8088
#    RBAC            → <central_ip>:9082
#    IR-To-Code AST  → <central_ip>:8082   (internal: ir-to-code:8082)
#    AI Code Gen     → <central_ip>:9000   (internal: ai-codegen:9000)
#    MongoDB         → <central_ip>:27017  (internal: mongo:27017)
#    Keycloak        → <central_ip>:9080
# ============================================================

if [ $# -lt 2 ]; then
    echo "Usage: $0 <instance_name> <base_port> [central_ip]"
    echo ""
    echo "Examples:"
    echo "  $0 user1 8000"
    echo "  $0 user2 8100 172.16.193.5"
    exit 1
fi

INSTANCE_NAME="$1"
BASE_PORT="$2"
CENTRAL_IP="${3:-172.16.193.5}"

# ── Calculate per-instance ports ─────────────────────────────
PORT_FE=$((BASE_PORT))
PORT_BE=$((BASE_PORT + 1))
PORT_DB=$((BASE_PORT + 2))
PORT_DMS=$((BASE_PORT + 3))
PORT_WORKFLOW=$((BASE_PORT + 4))
PORT_VAULT=$((BASE_PORT + 5))

# ── Detect host IP ───────────────────────────────────────────
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
[ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')
[ -z "$HOST_IP" ] && HOST_IP="127.0.0.1"

# ── Create instance directory ────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTANCE_DIR="$SCRIPT_DIR/instances/$INSTANCE_NAME"
mkdir -p "$INSTANCE_DIR"

echo "========================================================"
echo "     Creating RASP Instance: $INSTANCE_NAME"
echo "========================================================"
echo ""
echo "  ── Instance-specific services ────────────────────────"
echo "  Host IP:          $HOST_IP"
echo "  Frontend Port:    $PORT_FE  → http://$HOST_IP:$PORT_FE"
echo "  Backend Port:     $PORT_BE  → http://$HOST_IP:$PORT_BE"
echo "  DB Port:          $PORT_DB  → $HOST_IP:$PORT_DB"
echo "  DMS Port:         $PORT_DMS → http://$HOST_IP:$PORT_DMS"
echo "  Workflow Port:    $PORT_WORKFLOW"
echo "  Vault Port:       $PORT_VAULT"
echo ""
echo "  ── Shared central services (on $CENTRAL_IP) ─────────"
echo "  Keycloak:         http://$CENTRAL_IP:9080/admin/"
echo "  MongoDB:          $CENTRAL_IP:27017"
echo "  Collab Server:    http://$CENTRAL_IP:8088"
echo "  RBAC:             http://$CENTRAL_IP:9082"
echo "  IR-To-Code (AST): http://$CENTRAL_IP:8082"
echo "  AI Code Gen:      http://$CENTRAL_IP:9000"
echo "  AI Code Gen Docs: http://$CENTRAL_IP:9000/docs"
echo "========================================================"

# ── Generate instance .env file ──────────────────────────────
ENV_FILE="$INSTANCE_DIR/.env"
cat > "$ENV_FILE" <<EOF
# Auto-generated for instance: $INSTANCE_NAME
# Created: $(date -Iseconds)

PROJECT_NAME=$INSTANCE_NAME

# ── Host IPs ──────────────────────────────────────────────────
HOST_IP=$HOST_IP
CENTRAL_IP=$CENTRAL_IP

# ── Per-instance port assignments (base=$BASE_PORT) ───────────
PORT_FE=$PORT_FE
PORT_BE=$PORT_BE
PORT_DB=$PORT_DB
PORT_DMS=$PORT_DMS
PORT_WORKFLOW=$PORT_WORKFLOW
PORT_VAULT=$PORT_VAULT

# ── Volume paths (Linux defaults) ─────────────────────────────
GENERATED_PATH=/opt/rasp/generated
SOURCE_PROJECT_PATH=/opt/rasp/rasp_backend_source

# ── Central service references ────────────────────────────────
# These are provided by the central docker-compose stack.
# Instances communicate via the central server's HOST_IP.
COLLAB_SERVER_URL=http://$CENTRAL_IP:8088
RBAC_URL=http://$CENTRAL_IP:9082
KEYCLOAK_URL=http://$CENTRAL_IP:9080
MONGO_HOST=$CENTRAL_IP
MONGO_PORT=27017

# AI / Code Generation central services
AI_CODEGEN_URL=http://$CENTRAL_IP:9000
IR_TO_CODE_URL=http://$CENTRAL_IP:8082
EOF

echo ""
echo "✅ Generated: $ENV_FILE"

# ── Symlink compose file into instance dir ───────────────────
COMPOSE_SOURCE="$SCRIPT_DIR/docker-compose.local.yml"
COMPOSE_LINK="$INSTANCE_DIR/docker-compose.local.yml"
if [ ! -f "$COMPOSE_LINK" ]; then
    ln -sf "$COMPOSE_SOURCE" "$COMPOSE_LINK"
fi

# ── Start the instance ───────────────────────────────────────
echo ""
echo "Starting instance '$INSTANCE_NAME' ..."

COMPOSE_CMD="docker compose"
docker compose version >/dev/null 2>&1 || COMPOSE_CMD="docker-compose"

$COMPOSE_CMD -p "$INSTANCE_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_SOURCE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================================"
    echo -e "\033[1;32m✅ Instance '$INSTANCE_NAME' is running!\033[0m"
    echo "========================================================"
    echo ""
    echo "  ── Instance services ────────────────────────────────"
    echo "  Frontend:   http://$HOST_IP:$PORT_FE"
    echo "  Backend:    http://$HOST_IP:$PORT_BE"
    echo "  DB:         $HOST_IP:$PORT_DB"
    echo "  DMS:        http://$HOST_IP:$PORT_DMS"
    echo "  Vault:      http://$HOST_IP:$PORT_VAULT"
    echo "  Workflow:   http://$HOST_IP:$PORT_WORKFLOW"
    echo ""
    echo "  ── Central services (shared) ─────────────────────────"
    echo "  RBAC:             http://$CENTRAL_IP:9082"
    echo "  Collab Server:    http://$CENTRAL_IP:8088"
    echo "  Keycloak Admin:   http://$CENTRAL_IP:9080/admin/"
    echo "  IR-To-Code (AST): http://$CENTRAL_IP:8082"
    echo "  AI Code Gen:      http://$CENTRAL_IP:9000"
    echo "  AI Code Gen Docs: http://$CENTRAL_IP:9000/docs"
    echo "========================================================"
else
    echo -e "\033[1;31m❌ Failed to start instance '$INSTANCE_NAME'.\033[0m"
    echo "Run: docker compose -p $INSTANCE_NAME -f $COMPOSE_SOURCE ps"
    echo "Run: docker compose -p $INSTANCE_NAME -f $COMPOSE_SOURCE logs"
    exit 1
fi
