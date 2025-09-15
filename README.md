docker login 172.16.202.56:5000

// username: ctri
// password: RaspPlatform@123

docker compose -f dev.docker-compose.yml pull

// Install on linux
sudo apt install mkcert

// Install on windows as administrator
winget install --id=FiloSottile.mkcert -e

// Create & install certs
// For linux
./create-certs.sh

// For windows
./create-certs.ps1

// Up all the services
docker compose -f dev.docker-compose.yml up -d

// Add to /etc/hosts (linux) or C:\Windows\System32\drivers\etc\hosts (windows)
127.0.0.1 rasp-keycloak.localhost
127.0.0.1 rasp-designer-fe.localhost
127.0.0.1 rasp-designer-be.localhost

// Now access links in the browser (chrome only)
https://rasp-keycloak.localhost
https://rasp-designer-fe.localhost
