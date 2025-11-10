#!/bin/bash

cd "/home/ctri/Desktop/RASPutin/rasp-fe/Drag-Drop(RFE)"
docker build -t 172.16.202.56:5000/rasp-designer-fe:latest .
echo "Finished building RFE"

cd "/home/ctri/Desktop/RASPutin/rasp-fe/Drag-Drop(RBE)"
docker build -t 172.16.202.56:5000/rasp-designer-be:latest .
echo "Finished building RBE"


cd "/home/ctri/Desktop/RASPutin/RASP-RBAC"
docker build -t 172.16.202.56:5000/rasp-rbac:latest .
echo "Finished building RBAC"

cd "/home/ctri/Desktop/RASPutin"
docker compose up -d