# Threat Model — MSU ANPR & Vehicle Access-Control Platform

Status: DRAFT — for review by MSU information security, campus security, and
privacy/legal governance before any production connection to real cameras or
gate controllers.

## 1. Assets

| Asset | Sensitivity |
|---|---|
| Vehicle plate + authorization records | Confidential |
| Evidence images (plate crops, context frames) | Confidential/Restricted |
| Audit logs | Restricted (integrity-critical) |
| Officer/admin credentials | Restricted |
| Gate-controller command channel | Safety-critical |
| Camera credentials/streams | Confidential |
| Model/OCR configuration and thresholds | Internal |
| Flag/incident records | Restricted |

## 2. Threat Actors

- External network attacker (internet or campus-adjacent network)
- Malicious or coerced insider (officer, admin, contractor)
- Compromised credential (phished/reused password)
- Compromised or spoofed camera / edge device
- Compromised gate-controller channel
- Opportunistic physical tamperer (camera, edge box, cabling)

## 3. Attack Surfaces

- Public-facing web dashboard / API gateway
- Camera network and RTSP/API endpoints
- Edge device and its local buffer/sync channel
- Gate-controller command interface
- Database and object storage
- Administrative configuration interfaces
- Message broker (event bus)
- Third-party integrations (identity, SIEM, notification)

## 4. Key Threats and Mitigations

| # | Threat | Impact | Mitigation |
|---|---|---|---|
| T1 | Credential-stuffing / brute force against officer/admin login | Unauthorized access | Argon2id hashing, rate limiting, account lockout, MFA for privileged roles |
| T2 | Frontend-only authorization bypass (e.g., hidden "Delete" button called via API) | Privilege escalation | All permissions re-checked server-side; RBAC enforced at API layer, tested explicitly (FR/NFR + role tests) |
| T3 | SQL injection / IDOR on vehicle or event endpoints | Data exposure/corruption | Parameterized queries (SQLAlchemy), object-level authorization checks on every resource access |
| T4 | Compromised camera credentials used to pivot into application network | Lateral movement | VLAN segmentation, unique per-camera/per-edge credentials, cameras never reach DB directly |
| T5 | Malicious/spoofed edge device injecting false detection events | False authorization or denial-of-service on dashboard | Per-device authentication/certificates, event schema validation, signed sync payloads |
| T6 | Replay or duplication of gate-open commands | Unsafe or unintended gate operation | Command idempotency keys, retry limits, controller acknowledgement + physical sensor confirmation before state is reported as OPEN/CLOSED |
| T7 | Fuzzy-match plate manipulation (e.g., altering a plate to resemble an authorized one) | Unauthorized entry | No automatic fuzzy-match authorization (FR-015); near-matches always routed to manual verification |
| T8 | Tampering with audit logs to hide unauthorized access | Loss of accountability | Append-only/tamper-evident audit storage, no delete permission for ordinary roles, hash-chaining considered for high-value records |
| T9 | Bulk export or scraping of vehicle movement history by an insider | Privacy violation, stalking risk | Aggregate-by-default reporting, elevated permission + audited reason for detailed/historical export, rate limiting on bulk endpoints |
| T10 | Denial of service against ANPR/authorization service during peak traffic | Gate queue buildup, safety risk from unsafe workarounds | Queue backpressure, dead-letter handling, safe degraded-mode behavior (manual verification, never auto-authorize) |
| T11 | Compromise of gate-controller network from a corporate/public network | Physical security bypass | Network segmentation, gate controllers never internet-reachable, controller command source restricted to Gate Integration Service |
| T12 | Model/threshold manipulation by an unauthorized admin to force false authorizations | Systemic false-authorization | Versioned, audited configuration changes; four-eyes control recommended for threshold and automatic-mode changes |
| T13 | Data breach of evidence image storage | Exposure of sensitive imagery | Signed short-lived URLs only, no public storage paths, encryption at rest, per-access audit event on image view |
| T14 | Insider misuse of "automatic mode" without operational validation | Unsafe unattended gate operation | Automatic mode OFF by default; requires explicit health checks across every dependency and administrative approval (FR-024) |
| T15 | Man-in-the-middle on camera or gate-controller links | Command/data tampering | TLS/certificate-based authentication where supported by hardware, VLAN isolation as compensating control where TLS is not supported by legacy hardware |

## 5. Audit Events (minimum set)

LOGIN, LOGOUT, VEHICLE_CREATED, VEHICLE_UPDATED, AUTHORIZATION_CREATED,
AUTHORIZATION_REVOKED, FLAG_CREATED, FLAG_REMOVED, ACCESS_APPROVED,
ACCESS_DENIED, OCR_CORRECTED, GATE_COMMAND, USER_CREATED, USER_ROLE_CHANGED,
SYSTEM_SETTING_CHANGED, REPORT_EXPORTED, IMAGE_ACCESSED.

## 6. Residual Risk / Items Requiring MSU Decision

- Whether legacy gate-controller hardware supports TLS/mutual authentication (if not, VLAN isolation is a compensating control only, not equivalent to cryptographic authentication).
- Final data classification levels for vehicle movement history under MSU policy.
- Whether four-eyes (dual authorization) is mandated for enabling Automatic Mode, large exports, and retention changes (recommended; final decision is MSU's).
- Scope of penetration testing prior to go-live and its authorization boundaries around live safety-critical gate hardware (recommend testing against a non-production gate simulator/staging environment for anything that could trigger physical movement).

## 7. Explicit Exclusions From This Threat Model

Facial recognition, biometric identification, and integration with external
government/police/insurance databases are out of scope by design (see SRS §6)
and are therefore not modeled here; introducing them would require a new,
separate threat model and governance review.
