#!/bin/bash

# Script to start Collab Central Server on Linux
echo "----------------------------------------"
echo "    COLLAB CENTRAL SERVER STARTUP       "
echo "----------------------------------------"

# 1. Get the current IPv4 address
CURRENT_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(hostname -I | awk '{print $1}')
fi
if [ -z "$CURRENT_IP" ]; then
    echo "❌ Error: Could not detect IP address."
    exit 1
fi

echo -e "Detected IP Address: \033[1;33m$CURRENT_IP\033[0m"
export HOST_IP=$CURRENT_IP

# 2. Update Keycloak configuration with IP if realm file exists
if [ -d "dev_keycloak_realm_data" ]; then
    echo "Updating Keycloak configuration with IP: $CURRENT_IP..."
    sed -i "s/localhost/$CURRENT_IP/g" dev_keycloak_realm_data/realm-export.json
    sed -i "s/127.0.0.1/$CURRENT_IP/g" dev_keycloak_realm_data/realm-export.json
    sed -i "s/172.16.[0-9]\+.[0-9]\+/$CURRENT_IP/g" dev_keycloak_realm_data/realm-export.json
fi

# 3. Login to Docker Registry (needed if Collab-Server relies on rasp-platform base image)
echo "Ensuring Docker Registry access for base images..."
docker login 172.16.202.56:5000 -u ctri -p RaspPlatform@123 || {
    echo "⚠️ Auto-login failed but trying to proceed anyway (image might already be pulled)..."
}

# 4. Start Docker Configuration
echo -e "\033[1;32mBuilding and Starting Docker Containers...\033[0m"

if docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.collab-central.yml up -d --build
else
    docker-compose -f docker-compose.collab-central.yml up -d --build
fi

if [ $? -eq 0 ]; then
    echo "----------------------------------------"
    echo -e "\033[1;32m✅ Collab Central Deployed Successfully!\033[0m"
    echo "----------------------------------------"
    echo "Collab Backend:  http://$CURRENT_IP:8082"
    echo "Keycloak:        http://$CURRENT_IP:8080/admin/"
    echo "MongoDB:         $CURRENT_IP:27017"
    echo "----------------------------------------"
else
    echo -e "\033[1;31m❌ Docker failed to start.\033[0m"
fi
