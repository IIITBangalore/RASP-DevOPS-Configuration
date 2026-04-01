# RASP Distributed Collaborative System — QA End-to-End Test Plan

## Overview
This test plan validates the distributed architecture of the RASP platform, ensuring that local-first isolation, central synchronization, centralized RBAC enforcement, conflict resolution, and failure recoveries function correctly. 

The test simulates two users—**User A** and **User B**—interacting with the **same application** across their respective isolated local instances.

---

## PART 1 — TEST SETUP

### Target Environment
- **Central Server IP:** `172.16.202.56`
- **Host Machine IP:** `127.0.0.1` (or your local IP)

### User Instances
**User A (Instance 1)**
- Frontend: `http://127.0.0.1:8000`
- Backend (RBE): `http://127.0.0.1:8001`
- DB: MySQL (Port `8002`)

**User B (Instance 2)**
- Frontend: `http://127.0.0.1:8100`
- Backend (RBE): `http://127.0.0.1:8101`
- DB: MySQL (Port `8102`)

### Central Services
- Keycloak: `http://172.16.202.56:9080`
- Collab Server: `http://172.16.202.56:8088`
- RBAC Service: `http://172.16.202.56:9082`

### Preconditions
1. System deployed using `.\start-simulation.ps1 -numUsers 2 -CentralIP 172.16.202.56`.
2. Both **User A** and **User B** exist in Keycloak (`myRealm`).
3. Log in as User A on `http://127.0.0.1:8000`.
4. Log in as User B on `http://127.0.0.1:8100`.

---

## PART 2 — TEST FLOW (STEP-BY-STEP)

### STEP 1: Local App Creation (User A)
**Action:** User A creates a new app named `QA-App`.
**Flow:** UI → User A RBE → User A MySQL.
**Validations:**
1. ✅ **Local DB:** `QA-App` exists in User A MySQL (`visual_app_design` DB).
2. ✅ **Isolation:** `QA-App` DOES NOT exist in User B MySQL.
3. ✅ **No Central Calls:** Central Mongo and Collab Server show no related activity.

### STEP 2: Share App (User A)
**Action:** User A clicks "Share" or "Publish To Central" for `QA-App`.
**Flow:** User A RBE → Collab Server → Central Mongo → Central RBAC.
**Validations:**
1. ✅ **Central State:** App structure serialized and stored in Central Mongo (`traveler_db.projects`).
2. ✅ **RBAC Assignments:** Central RBAC API logs show `QA-App` registered with User A as `OWNER`.
3. ✅ **Metadata:** App version set to `1.0.0` (or revision `1`).

### STEP 3: Access by User B
**Action:** User A grants User B `EDITOR` access via the UI (which calls RBAC). User B navigates to the "Shared With Me" / "Central Hub" section and opens `QA-App`.
**Flow:** User B RBE → Collab Server → Central Mongo → User B RBE → User B MySQL.
**Validations:**
1. ✅ **Local Copy:** `QA-App` metadata and components stored in User B MySQL.
2. ✅ **UI Visibility:** `QA-App` loads successfully in User B's designer.
3. ✅ **RBAC Check:** Logs show RBAC authorizing User B for `READ` access on `QA-App`.

### STEP 4: Independent Editing (Divergence)
**Action:** 
- User A modifies the app (e.g., changes a button label to "A change"). Saves locally.
- User B modifies the app (e.g., changes the same button label to "B change"). Saves locally.
**Validations:**
1. ✅ **No Immediate Sync:** Neither central Mongo nor the other user's DB reflects the changes yet.
2. ✅ **Local Isolation:** Both local MySQL DBs have diverged correctly state without affecting each other.

### STEP 5: Sync User A
**Action:** User A triggers "Sync to Central" / "Push".
**Flow:** User A RBE → Collab Server → Central Mongo.
**Validations:**
1. ✅ **Central Updated:** Button label in Central Mongo is now "A change".
2. ✅ **Version Bump:** Central version increments (e.g., `1.0.1` or revision `2`).
3. ✅ **No Conflicts:** Sync succeeds smoothly.

### STEP 6: Sync User B (Conflict Case)
**Action:** User B triggers "Sync to Central".
**Flow:** User B RBE → Collab Server (checks revision).
**Validations:**
1. ✅ **Conflict Detected:** RBE or Collab Server detects that User B's base revision (`1`) is older than Central's current revision (`2`).
2. ✅ **Request Rejected:** Collab API returns HTTP `409 Conflict`.
3. ✅ **UI Feedback:** User B receives a conflict warning with options.

### STEP 7: Conflict Resolution
**Action:** User B selects "Overwrite Central" or resolves the merge manually and pushes again.
**Validations:**
1. ✅ **Final State Published:** Central Mongo reflects the resolved state.
2. ✅ **Version Bump:** Central revision increments to `3`.

---

## PART 3 — RBAC VALIDATION

### Access Removal Test
**Action:** User A modifies `QA-App` permissions via UI, revoking User B's access.
**Flow:** User A RBE → RBAC Service.

### Enforced Denial Test
**Action 1:** User B attempts to fetch the latest state of `QA-App` from central.
**Validation 1:** ✅ RBE requests fetch from Collab. RBAC denies it. UI shows "Access Denied / Forbidden" (HTTP `403`).

**Action 2:** User B attempts to push local changes for `QA-App` to central.
**Validation 2:** ✅ Push request denied by RBAC (HTTP `403`). User B local state remains intact but cannot sync.

---

## PART 4 — FAILURE TESTS

### 1. Central MongoDB Down
**Action:** Stop central Mongo container: `docker stop mongo`. User A attempts to push a sync.
**Validations:**
1. ✅ Central Collab / RBAC returns HTTP `503` or `500` regarding DB unavailability.
2. ✅ User A UI gracefully shows "Sync failed - Central Database offline".
3. ✅ local data remains completely intact and editable.

### 2. Central RBAC Down
**Action:** Restart Mongo. Stop RBAC: `docker stop rasp-rbac`. User B attempts to access a shared app.
**Validations:**
1. ✅ RBE API calls to `http://172.16.202.56:9082/api/*` timeout or connection refused.
2. ✅ RBE fails closed (HTTP `403` or `502` Bad Gateway).
3. ✅ User cannot fetch or sync central data, maintaining security isolation. RBE logs show `Connection refused` to RBAC URL.

### 3. Collab Server Down
**Action:** Stop Collab Server.
**Validations:**
1. ✅ RBE calls to Collab API fail.
2. ✅ Sync operations fail gracefully preserving local state.

---

## PART 5 — EXPECTED LOGS

During **STEP 2 (Share App)** and **STEP 5 (Sync A)**, verify these log markers:

### User A RBE (`docker compose -p user1 logs -f rasp-designer-be`)
```text
[INFO] Pushing project QA-App to central collab server...
[INFO] Fetching RBAC permissions for POST request...
[INFO] Sync successful. Local revision updated to 2.
```

### Collab Server (`docker logs collab-server -f`)
```text
[INFO] Received sync request for QA-App from User A.
[INFO] Validating token with Keycloak...
[INFO] Verifying WRITE permissions with RBAC...
[INFO] Updating central Mongo document. Revision incremented from 1 -> 2.
```

### RBAC Service (`docker logs rasp-rbac -f`)
```text
[INFO] AuthCheck POST /api/v1/projects/QA-App user=User A
[INFO] Result: Authorized (Role: OWNER)
```

---

## PART 6 — AUTOMATION (cURL Commands)

*Replace `$TOKEN_A` and `$TOKEN_B` with valid Keycloak JWTs.*

**1. Create App (User A)**
```bash
curl -X POST http://127.0.0.1:8001/api/projects \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"name": "QA-App", "schema": {}}'
```

**2. Push App to Central (User A)**
```bash
curl -X POST http://127.0.0.1:8001/api/sync/push \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"projectId": "QA-App_ID"}'
```

**3. Attempt Sync without Permission (User B - Verification)**
*After revoking access:*
```bash
# Direct call to Collab API bypassing RBE (testing security at the edge)
curl -X GET http://172.16.202.56:8088/api/projects/QA-App_ID \
  -H "Authorization: Bearer $TOKEN_B" 
# EXPECTED RESPONSE: 403 Forbidden
```

---

## PART 7 — SUCCESS CRITERIA

The QA sign-off is granted **ONLY IF**:
1. ✅ **Local-First Works:** App creation and editing work flawlessly even when central services are down.
2. ✅ **Sync Works:** Changes flow from User A → Central → User B without corruption.
3. ✅ **Conflict Detection Works:** Outdated syncs are aggressively rejected by the central Collab Server with HTTP `409`.
4. ✅ **RBAC Enforced Centrally:** All fetch/sync calls are intercepted and authorized by the central `rasp-rbac` service.
5. ✅ **No DB Leakage:** User A's unshared local projects never appear in User B's MySQL.
6. ✅ **Failure Recovery:** System degrades gracefully (local editing continues) when Central MongoDB, RBAC, or Collab drop offline, and sync resumes when they return.
