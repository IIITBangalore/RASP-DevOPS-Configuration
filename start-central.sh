#!/bin/bash
set -euo pipefail

# ============================================================
#  RASP Central Server Startup (Linux)
#  Services: Keycloak, PostgreSQL, MongoDB, Collab Server,
#            RBAC, IR-To-Code (AST), AI Code Generation
#
#  Usage:
#    ./start-central.sh            # pull images, start all
#    ./start-central.sh --build    # (re)build ai-codegen &
#                                  #  ir-to-code from source
# ============================================================

BUILD_FLAG=""
for arg in "$@"; do
    case "$arg" in
        --build|-b) BUILD_FLAG="--build" ;;
        --help|-h)
            echo "Usage: $0 [--build]"
            echo "  --build  Force (re)build of ai-codegen and ir-to-code from source"
            exit 0
            ;;
    esac
done

echo "========================================================"
echo "          RASP CENTRAL SERVER STARTUP                   "
echo "========================================================"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Detect host IP ─────────────────────────────────────────
CURRENT_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
[ -z "$CURRENT_IP" ] && CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Error: Could not detect IP address."
    exit 1
fi

echo -e "Detected IP Address: \033[1;33m$CURRENT_IP\033[0m"
export HOST_IP="$CURRENT_IP"

# ── 2. Update Keycloak realm with current IP ──────────────────
REALM_FILE="dev_keycloak_realm_data/realm-export.json"
if [ -f "$REALM_FILE" ]; then
    echo "Updating Keycloak realm config with IP: $CURRENT_IP ..."
    sed -i "s/localhost/$CURRENT_IP/g"                      "$REALM_FILE"
    sed -i "s/127\.0\.0\.1/$CURRENT_IP/g"                  "$REALM_FILE"
    sed -i "s/172\.16\.[0-9]\+\.[0-9]\+/$CURRENT_IP/g"    "$REALM_FILE"
fi

# ── 3. Docker registry login ──────────────────────────────────
echo "Logging into Docker Registry ..."
docker login 172.16.202.56:5000 -u ctri -p RaspPlatform@123 2>/dev/null || {
    echo "⚠️  Auto-login failed. Trying manual login ..."
    docker login 172.16.202.56:5000 || { echo "❌ Login failed."; exit 1; }
}

# ── 4. Ensure volume / data directories exist ─────────────────
mkdir -p /opt/rasp/generated
mkdir -p /opt/rasp/rasp_backend_source
export GENERATED_PATH=/opt/rasp/generated
export SOURCE_PROJECT_PATH=/opt/rasp/rasp_backend_source

# ── 5. Validate AI-Code-Generation .env ──────────────────────
AI_CODEGEN_ENV="${SCRIPT_DIR}/../AI-Code-Generation/.env"
if [ ! -f "$AI_CODEGEN_ENV" ]; then
    AI_CODEGEN_ENV_EXAMPLE="${SCRIPT_DIR}/../AI-Code-Generation/.env.example"
    if [ -f "$AI_CODEGEN_ENV_EXAMPLE" ]; then
        echo "⚠️  AI-Code-Generation/.env not found. Copying from .env.example ..."
        cp "$AI_CODEGEN_ENV_EXAMPLE" "${SCRIPT_DIR}/../AI-Code-Generation/.env"
        echo "   ➜ Edit ${SCRIPT_DIR}/../AI-Code-Generation/.env and add your API keys before production use."
    else
        echo "❌ AI-Code-Generation/.env is missing and no .env.example found."
        echo "   Create the file at: ${SCRIPT_DIR}/../AI-Code-Generation/.env"
        exit 1
    fi
fi
export AI_CODEGEN_ENV_FILE="$AI_CODEGEN_ENV"

# ── 6. Start services ─────────────────────────────────────────
echo -e "\n\033[1;32mStarting Central Server containers ...\033[0m"
[ -n "$BUILD_FLAG" ] && echo "⚙️  --build flag set: will build ai-codegen and ir-to-code from source."

COMPOSE_CMD="docker compose"
docker compose version >/dev/null 2>&1 || COMPOSE_CMD="docker-compose"

$COMPOSE_CMD -f docker-compose.central.yml up -d $BUILD_FLAG

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================================"
    echo -e "\033[1;32m✅ Central Server Deployed Successfully!\033[0m"
    echo "========================================================"
    echo ""
    echo "  ── Core Infrastructure ──────────────────────────────"
    echo "  Keycloak:         http://$CURRENT_IP:9080/admin/"
    echo "  MongoDB:          $CURRENT_IP:27017"
    echo ""
    echo "  ── Platform Services ────────────────────────────────"
    echo "  Collab Server:    http://$CURRENT_IP:8088"
    echo "  RBAC Service:     http://$CURRENT_IP:9082"
    echo ""
    echo "  ── AI / Code Generation ─────────────────────────────"
    echo "  IR-To-Code (AST): http://$CURRENT_IP:8082"
    echo "  AI Code Gen:      http://$CURRENT_IP:9000"
    echo "  AI Code Gen Docs: http://$CURRENT_IP:9000/docs"
    echo ""
    echo "========================================================"
    echo ""
    echo -e "\033[1;35mNOTE: If this is a new IP, update Keycloak Redirect URIs to '*'\033[0m"
    echo -e "\033[1;35mNOTE: Edit AI-Code-Generation/.env to configure API keys.\033[0m"
    echo ""
    echo "  Health checks:"
    echo "  curl http://$CURRENT_IP:9000/docs                  # ai-codegen"
    echo "  curl http://$CURRENT_IP:8082/api/v1/generator/health  # ir-to-code"
    echo ""
else
    echo -e "\033[1;31m❌ Docker Compose failed to start one or more services.\033[0m"
    echo "Run: docker compose -f docker-compose.central.yml ps"
    echo "Run: docker compose -f docker-compose.central.yml logs <service>"
    exit 1
fi
