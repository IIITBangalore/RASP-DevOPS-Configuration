#!/bin/bash

echo "Creating self-signed certificates"

# Create certs directory if it doesn't exist
mkdir -p certs

# Move into the certs directory
cd certs || exit

# Generate certificates
mkcert rasp-designer-be.localhost
mkcert rasp-designer-fe.localhost
mkcert rasp-keycloak.localhost

echo "Installing certificates"
