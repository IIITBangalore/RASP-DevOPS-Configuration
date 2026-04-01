# RASP Production Deployment Guide

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Central Server Deployment](#central-server-deployment)
3. [Multi-User Instance Management](#multi-user-instance-management)
4. [Networking Explained](#networking-explained)
5. [Scaling Strategy](#scaling-strategy)
6. [Failure Cases & Mitigation](#failure-cases--mitigation)
7. [Production Hardening](#production-hardening)
8. [Quick Reference](#quick-reference)

---

## Architecture Overview

```
┌──────────────────── CENTRAL SERVER (172.16.202.56) ────────────────────┐
│                                                                        │
│  ┌───────────┐  ┌──────────┐  ┌─────────┐  ┌───────┐  ┌──────────┐  │
│  │ PostgreSQL│──│ Keycloak │  │ MongoDB │──│ RBAC  │  │  Collab  │  │
│  │  :5432    │  │  :9080   │  │ :27017  │  │ :9082 │  │  :8088   │  │
│  └───────────┘  └──────────┘  └─────────┘  └───┬───┘  └────┬─────┘  │
│                                                 │           │         │
└─────────────────────────────────────────────────┼───────────┼─────────┘
                                                  │           │
                      ┌───────────────────────────┼───────────┼──────┐
                      │   HTTP API calls over network                │
                      ▼                           ▼                  │
┌──── USER 1 INSTANCE (base=8000) ────┐  ┌──── USER 2 (base=8100) ──┤
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌─────┐ │  │  (identical structure)   │
│ │  FE  │ │  BE  │ │MySQL │ │ DMS │ │  │                          │
│ │:8000 │→│:8001 │ │:8002 │ │:8003│ │  │                          │
│ └──────┘ └──┬───┘ └──────┘ └─────┘ │  │                          │
│             │                       │  │                          │
│    RBE calls CENTRAL for:           │  │                          │
│    • RBAC (authorization)           │  │                          │
│    • Collab (sync/shared state)     │  │                          │
│    • Keycloak (auth tokens)         │  │                          │
│    Uses LOCAL MySQL for data        │  │                          │
└─────────────────────────────────────┘  └──────────────────────────┘
```

### Communication Flow
```
Frontend → RBE → RBAC (central :9082)     ← authorization checks
Frontend → RBE → Collab Server (:8088)    ← shared state / sync
Frontend → RBE → MySQL (local)            ← user's project data
Frontend → RBE → Keycloak (central :9080) ← token validation
```

### Key Environment Variables
| Variable | Purpose | Used By |
|----------|---------|---------|
| `HOST_IP` | This machine's IP (for browser-facing URLs) | FE, BE |
| `CENTRAL_IP` | Central server's IP (for API calls) | BE, DMS |
| `PROJECT_NAME` | Unique instance name (e.g., `user1`) | All local |
| `PORT_FE/BE/DB/DMS` | Computed port assignments | All local |

---

## Central Server Deployment

### Prerequisites
- Linux server with Docker + Docker Compose v2
- Ports open: `9080`, `9082`, `8088`, `27017`
- Docker registry accessible at `172.16.202.56:5000`

### One-Command Deploy (from Windows dev machine)
```powershell
.\deploy-central.ps1 -TargetIP 172.16.202.56
```

### Manual Deploy (on Linux server)
```bash
# 1. Clone/copy the RASP-DevOPS-Configuration directory
# 2. Run:
chmod +x start-central.sh
sudo ./start-central.sh
```

### Verify Services
```bash
# Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test endpoints
curl -s http://localhost:9080/health/live    # Keycloak
curl -s http://localhost:9082/api/health     # RBAC
curl -s http://localhost:8088/api/health     # Collab
mongosh --eval "db.adminCommand('ping')"    # MongoDB
```

---

## Multi-User Instance Management

### Port Allocation Scheme

Each user gets a **100-port block**:

| User | Base Port | FE | BE | MySQL | DMS |
|------|-----------|------|------|-------|------|
| user1 | 8000 | 8000 | 8001 | 8002 | 8003 |
| user2 | 8100 | 8100 | 8101 | 8102 | 8103 |
| user3 | 8200 | 8200 | 8201 | 8202 | 8203 |
| ... | +100 | +0 | +1 | +2 | +3 |

**Max capacity**: ~570 users (ports up to 65000).

### Create an Instance

**Linux:**
```bash
./create-instance.sh user1 8000 172.16.202.56
./create-instance.sh user2 8100 172.16.202.56
```

**Windows:**
```powershell
.\create-instance.ps1 -Name user1 -BasePort 8000 -CentralIP 172.16.202.56
.\create-instance.ps1 -Name user2 -BasePort 8100 -CentralIP 172.16.202.56
```

### Destroy an Instance
```bash
./destroy-instance.sh user1              # removes containers + volumes
./destroy-instance.sh user1 --keep-data  # keeps MySQL data
```

### Batch Simulation (Local Dev)
```powershell
# Starts central server + N user instances automatically
.\start-simulation.ps1 -numUsers 5 -CentralIP 172.16.202.56
```

### Instance Directory Structure
```
RASP-DevOPS-Configuration/
├── instances/
│   ├── user1/
│   │   ├── .env                    # auto-generated
│   │   └── docker-compose.local.yml  # symlink
│   ├── user2/
│   │   └── ...
│   └── ...
```

---

## Networking Explained

### Why RBAC Must Be Centralized

RBAC manages **roles, permissions, and project access** stored in MongoDB. If each user had their own RBAC:
- **Inconsistent permissions**: User A grants access to User B, but User B's RBAC doesn't know about it
- **Data duplication**: Every RBAC instance would need its own MongoDB or share one — sharing defeats the purpose of isolation
- **Single source of truth**: Authorization decisions must be consistent across all users

### `localhost` vs `HOST_IP` vs `CENTRAL_IP`

| Term | Resolves To | Used For |
|------|------------|----------|
| `localhost` / `127.0.0.1` | The container itself | **Never use** for cross-container communication |
| `HOST_IP` | The machine running this instance | Browser-facing URLs (FE, BE redirect URIs, Keycloak login redirects) |
| `CENTRAL_IP` | The central server's IP | API calls from RBE → RBAC, Collab, Keycloak, MongoDB |

### Cross-Machine Networking

```
┌─── Machine A (central) ───┐     ┌─── Machine B (instances) ──┐
│  Docker bridge network     │     │  Docker bridge network      │
│  ┌──────┐  ┌──────┐       │     │  ┌──────┐  ┌──────┐        │
│  │ RBAC │  │Mongo │       │     │  │  RBE │  │MySQL │        │
│  │ :9082│  │:27017│       │     │  │:8001 │  │:8002 │        │
│  └──┬───┘  └──┬───┘       │     │  └──┬───┘  └──────┘        │
│     │    internal          │     │     │   internal            │
├─────┼──────────┼───────────┤     ├─────┼──────────────────────┤
│  port 9082  port 27017     │     │  port 8001                 │
└─────┬──────────┬───────────┘     └─────┬──────────────────────┘
      │          │                       │
      └──────────┼───────────────────────┘
           Physical network (e.g., 172.16.x.x)
```

Containers talk **cross-machine** through **published ports** on the host's network interface. The `CENTRAL_IP` env var ensures RBE knows the routable IP of the central server.

---

## Scaling Strategy

### 10 → 100 Users

| Bottleneck | Symptom | Solution |
|------------|---------|----------|
| **RBAC** (single Java process) | Slow authorization responses (>500ms) | Run 2–3 RBAC replicas behind a load balancer (HAProxy/NGINX) |
| **MongoDB** | High query latency, lock contention | Deploy as a 3-node replica set; add read secondaries |
| **Collab Server** | WebSocket connection limits, memory pressure | Horizontal scale with sticky sessions (NGINX `ip_hash`) |
| **Keycloak** | Login/token-issuance delays | Add a second Keycloak node with shared PostgreSQL |
| **Port space** | Running out of ports (>570 users) | Move instances to multiple host machines, or use NGINX per-instance reverse proxy |

### Recommended Architecture at 100 Users

```
                    ┌── NGINX (LB) ──┐
                    │                 │
              ┌─────┴────┐    ┌──────┴────┐
              │ RBAC × 2 │    │ Collab × 2│
              └─────┬────┘    └──────┬────┘
                    │                │
              ┌─────┴────────────────┴────┐
              │   MongoDB Replica Set     │
              │   (Primary + 2 Secondary) │
              └───────────────────────────┘
```

### Multi-Machine Instance Distribution

At ~50+ users per host, distribute instances across machines:
```bash
# Machine B
./create-instance.sh user51 13000 172.16.202.56

# Machine C
./create-instance.sh user101 18000 172.16.202.56
```
All instances point to the same `CENTRAL_IP`.

---

## Failure Cases & Mitigation

### 1. RBAC Service Down

**Impact**: RBE cannot check permissions → API calls that require authorization fail with 5xx.

**What happens**:
- Local editing (MySQL-only operations) **continues to work**
- Collaboration features (save to Mongo, share, publish) **fail**
- Users see "Authorization service unavailable" errors

**Mitigation**:
- RBE should implement a **circuit breaker** with cached permissions (TTL 60s)
- Docker `restart: unless-stopped` auto-recovers from crashes
- Monitor with: `curl http://CENTRAL_IP:9082/api/health`

### 2. Keycloak Unreachable

**Impact**: No new logins possible. Existing sessions with valid tokens continue working until token expiry.

**What happens**:
- Users with active sessions: **no immediate impact**
- Token refresh fails → user logged out after token expires (default 5 min)
- New users: **cannot log in at all**

**Mitigation**:
- Increase token expiry to 30 min in Keycloak admin
- Monitor Keycloak health: `curl http://CENTRAL_IP:9080/health/live`
- PostgreSQL failure cascades here — ensure `postgres_data` volume is durable

### 3. MongoDB Down

**Impact**: RBAC cannot read permissions, Collab cannot sync state.

**What happens**:
- RBAC: falls back to denying all requests (fail-closed)
- Collab: all real-time sync stops
- Local MySQL operations: **unaffected**

**Mitigation**:
- Use MongoDB replica set (3 nodes) for automatic failover
- Enable `--wiredTigerCacheSizeGB` to prevent OOM
- Backup: `mongodump --host CENTRAL_IP --out /backup/$(date +%F)`

### 4. Network Partition (Local ↛ Central)

**Impact**: The local instance is completely cut off from central services.

**What happens**:
- RBE: all central API calls timeout (RBAC, Collab, Keycloak)
- Local editing: **continues** (MySQL is local)
- No permission checks → cannot save/publish/share

**Mitigation**:
- RBE timeout config: set `RBAC_TIMEOUT=5000` (5s, fail fast)
- Offline mode: queue operations and replay when connectivity returns

---

## Production Hardening

### 1. NGINX Reverse Proxy

Install and configure on the central server:
```bash
sudo apt install nginx -y
sudo cp config/nginx.conf /etc/nginx/conf.d/rasp.conf
sudo nginx -t && sudo systemctl reload nginx
```

See [config/nginx.conf](file:///c:/Users/Aman/Desktop/RASP/RASP-DevOPS-Configuration/config/nginx.conf) for the full config with:
- HTTP → HTTPS redirect
- SSL termination
- Rate limiting (30 req/s per IP)
- WebSocket proxy for Collab
- Security headers

### 2. SSL Setup

**Option A: Self-signed (dev/internal)**
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/rasp.key \
    -out /etc/nginx/ssl/rasp.crt \
    -subj "/CN=rasp.internal"
```

**Option B: Let's Encrypt (production with domain)**
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d rasp.yourdomain.com
```

### 3. Logging

**Centralized Docker logging** — add to each compose file:
```yaml
services:
  rasp-rbac:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
```

**View logs:**
```bash
docker logs rasp-rbac --tail 100 -f          # single service
docker compose -f docker-compose.central.yml logs -f  # all central
docker compose -p user1 logs -f               # specific instance
```

### 4. Backup Strategy

| Data | Location | Backup Command | Frequency |
|------|----------|---------------|-----------|
| MongoDB | Central server | `mongodump --host localhost --out /backup/mongo/$(date +%F)` | Daily |
| PostgreSQL (Keycloak) | Central server | `docker exec postgres pg_dump -U keycloak_db_user keycloak_db > /backup/pg/$(date +%F).sql` | Daily |
| MySQL (per user) | Each instance | `docker exec <name>-mysql mysqldump -uroot -proot visual_app_design > /backup/mysql/<name>-$(date +%F).sql` | Daily |
| Keycloak realm config | Central server | `cp -r dev_keycloak_realm_data /backup/keycloak/` | After changes |

**Automated backup script:**
```bash
#!/bin/bash
BACKUP_DIR="/backup/$(date +%F)"
mkdir -p "$BACKUP_DIR"

# MongoDB
mongodump --host localhost --out "$BACKUP_DIR/mongo"

# PostgreSQL
docker exec postgres pg_dump -U keycloak_db_user keycloak_db > "$BACKUP_DIR/keycloak.sql"

# All MySQL instances
for dir in instances/*/; do
    name=$(basename "$dir")
    docker exec "${name}-mysql" mysqldump -uroot -proot visual_app_design > "$BACKUP_DIR/${name}-mysql.sql" 2>/dev/null || true
done

echo "✅ Backup complete: $BACKUP_DIR"
```

---

## Quick Reference

### Commands Cheat Sheet

| Action | Command |
|--------|---------|
| **Deploy central (remote)** | `.\deploy-central.ps1 -TargetIP 172.16.202.56` |
| **Start central (local)** | `./start-central.sh` |
| **Create instance** | `./create-instance.sh user1 8000 172.16.202.56` |
| **Destroy instance** | `./destroy-instance.sh user1` |
| **Simulation (N users)** | `.\start-simulation.ps1 -numUsers 5` |
| **View central logs** | `docker compose -f docker-compose.central.yml logs -f` |
| **View instance logs** | `docker compose -p user1 logs -f` |
| **Check RBAC health** | `curl http://172.16.202.56:9082/api/health` |
| **Backup all** | `sudo ./backup.sh` |

### Service URLs (Default Central Server)

| Service | URL |
|---------|-----|
| Keycloak Admin | `http://172.16.202.56:9080/admin/` |
| Keycloak Auth | `http://172.16.202.56:9080/realms/myRealm` |
| RBAC API | `http://172.16.202.56:9082/api` |
| Collab API | `http://172.16.202.56:8088/api` |
| MongoDB | `172.16.202.56:27017` |

### Instance URLs (Example: user1 at base_port=8000)

| Service | URL |
|---------|-----|
| Frontend | `http://<HOST_IP>:8000` |
| Backend | `http://<HOST_IP>:8001` |
| MySQL | `<HOST_IP>:8002` |
| DMS | `http://<HOST_IP>:8003` |
