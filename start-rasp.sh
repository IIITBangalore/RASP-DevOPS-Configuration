#!/bin/bash

# Script to start RASP on Linux with dynamic IP detection

echo "----------------------------------------"
echo "       RASP SERVER STARTUP (Linux)      "
echo "----------------------------------------"

# 1. Get the current IPv4 address
# Try to parse from `ip route get 1.1.1.1` (most reliable for finding the interface with internet access)
CURRENT_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')

# Fallback if the above fails (e.g., offline) - grab first non-loopback IP
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(hostname -I | awk '{print $1}')
fi

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Error: Could not detect IP address."
    exit 1
fi

echo -e "Detected IP Address: \033[1;33m$CURRENT_IP\033[0m"

# 2. Set the HOST_IP environment variable
export HOST_IP=$CURRENT_IP
echo "Set HOST_IP = $CURRENT_IP"

# 2.1 Update realm-export.json with current IP
echo "Updating Keycloak configuration with IP: $CURRENT_IP..."
# Replace localhost, 127.0.0.1, and previous 172.x IPs with current IP in the JSON file
sed -i "s/localhost/$CURRENT_IP/g" dev_keycloak_realm_data/realm-export.json
sed -i "s/127.0.0.1/$CURRENT_IP/g" dev_keycloak_realm_data/realm-export.json
# Be careful with 172.16 regex, but safely replacing known patterns
sed -i "s/172.16.[0-9]\+.[0-9]\+/$CURRENT_IP/g" dev_keycloak_realm_data/realm-export.json

# 2.2 Login to Docker Registry
echo "Logging into Docker Registry as ctri..."
# Try auto-login with ctri (which worked for pushing images locally)
docker login 172.16.202.56:5000 -u ctri -p RaspPlatform@123

if [ $? -ne 0 ]; then
    echo "❌ Auto-login failed with 'ctri'."
    
    # Loop until login is successful
    while true; do
        echo "⚠️  Please enter Docker Registry credentials manually:"
        docker login 172.16.202.56:5000
        
        if [ $? -eq 0 ]; then
            echo "✅ Login successful!"
            break
        fi
        
        echo "❌ Login failed. Try again? (y/n)"
        read -r response
        if [[ "$response" != "y" ]]; then
            echo "Exiting..."
            exit 1
        fi
    done
fi

# 3. Start Docker Configuration
echo -e "\033[1;32mStarting Docker Containers...\033[0m"

# Ensure directories exist for volumes
mkdir -p generated
mkdir -p rasp_backend_source

# Set Linux-specific paths for volumes (Overrides defaults in docker-compose.yml)
export GENERATED_PATH=./generated
export SOURCE_PROJECT_PATH=./rasp_backend_source

# Check if docker-compose plugin is installed, otherwise use docker-compose
if docker compose version >/dev/null 2>&1; then
    docker compose -f dev.docker-compose.yml up -d
else
    docker-compose -f dev.docker-compose.yml up -d
fi

if [ $? -eq 0 ]; then
    echo "----------------------------------------"
    echo -e "\033[1;32m✅ RASP Deployed Successfully!\033[0m"
    echo "----------------------------------------"
    echo "Frontend:      http://$CURRENT_IP"
    echo "Backend:       http://$CURRENT_IP:9000"
    echo "Keycloak:      http://$CURRENT_IP:9080/admin/"
    echo "----------------------------------------"
    echo -e "\033[1;35mNOTE: If this is a new IP, update Keycloak Redirect URIs to '*'\033[0m"
else
    echo -e "\033[1;31m❌ Docker failed to start.\033[0m"
fi
