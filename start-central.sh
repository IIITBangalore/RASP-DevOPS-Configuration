#!/bin/bash
set -euo pipefail

# ============================================================
#  RASP Central Server Startup (Linux)
#  Services: Keycloak, PostgreSQL, MongoDB, Collab Server, RBAC
# ============================================================

echo "========================================"
echo "    RASP CENTRAL SERVER STARTUP         "
echo "========================================"

# ── 1. Detect host IP ──────────────────────────────────────
CURRENT_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
[ -z "$CURRENT_IP" ] && CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Error: Could not detect IP address."
    exit 1
fi

echo -e "Detected IP Address: \033[1;33m$CURRENT_IP\033[0m"
export HOST_IP="$CURRENT_IP"

# ── 2. Update Keycloak realm with current IP ────────────────
REALM_FILE="dev_keycloak_realm_data/realm-export.json"
if [ -f "$REALM_FILE" ]; then
    echo "Updating Keycloak realm config with IP: $CURRENT_IP ..."
    sed -i "s/localhost/$CURRENT_IP/g"                        "$REALM_FILE"
    sed -i "s/127\.0\.0\.1/$CURRENT_IP/g"                    "$REALM_FILE"
    sed -i "s/172\.16\.[0-9]\+\.[0-9]\+/$CURRENT_IP/g"      "$REALM_FILE"
fi

# ── 3. Docker registry login ───────────────────────────────
echo "Logging into Docker Registry ..."
docker login 172.16.202.56:5000 -u ctri -p RaspPlatform@123 2>/dev/null || {
    echo "⚠️  Auto-login failed. Trying manual login ..."
    docker login 172.16.202.56:5000 || { echo "❌ Login failed."; exit 1; }
}

# ── 4. Ensure volume directories exist ──────────────────────
mkdir -p /opt/rasp/generated
mkdir -p /opt/rasp/rasp_backend_source
export GENERATED_PATH=/opt/rasp/generated
export SOURCE_PROJECT_PATH=/opt/rasp/rasp_backend_source

# ── 5. Start services ──────────────────────────────────────
echo -e "\033[1;32mStarting Central Server containers ...\033[0m"

if docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.central.yml up -d
else
    docker-compose -f docker-compose.central.yml up -d
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo -e "\033[1;32m✅ Central Server Deployed Successfully!\033[0m"
    echo "========================================"
    echo "Keycloak:       http://$CURRENT_IP:9080/admin/"
    echo "MongoDB:        $CURRENT_IP:27017"
    echo "Collab Server:  http://$CURRENT_IP:8088"
    echo "RBAC Service:   http://$CURRENT_IP:9082"
    echo "========================================"
    echo ""
    echo -e "\033[1;35mNOTE: If this is a new IP, update Keycloak Redirect URIs to '*'\033[0m"
else
    echo -e "\033[1;31m❌ Docker failed to start.\033[0m"
    exit 1
fi
