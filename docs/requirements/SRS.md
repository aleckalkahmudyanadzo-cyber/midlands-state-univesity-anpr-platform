# System Requirements Specification (SRS)
## MSU Campus ANPR & Vehicle Access-Control Platform

Status: DRAFT — pending MSU governance, legal/privacy, information-security, and campus-security review.
Version: 0.1.0

---

## 1. Purpose and Scope

This platform assists trained Midlands State University (MSU) security personnel in
determining whether a vehicle approaching a controlled campus gate is authorized,
temporarily authorized, unknown, flagged, expired, revoked, or unable to be reliably
identified. It reads plates from approved camera feeds, compares recognition results
against authorized-vehicle records, and produces an access **recommendation** — not
an autonomous access **decision** — unless and until MSU formally approves automatic
operation for a defined, low-risk vehicle class under measured, monitored conditions.

Out of scope (this document): facial recognition, biometric identification, person
tracking, integration with external/government databases, and any capability not
explicitly authorized by MSU.

## 2. Definitions

| Term | Meaning |
|---|---|
| ANPR | Automatic Number Plate Recognition |
| Passage Event | A consolidated, deduplicated vehicle movement through a lane |
| Authorization | An institutional rule permitting a vehicle at a scope (campus/gate/direction/time) |
| Assisted Mode | System recommends, officer confirms, before any gate command issues |
| Automatic Mode | System may issue a gate command without a per-event officer confirmation, for an approved vehicle class, under approved conditions |

## 3. Actors / Roles

SECURITY_OFFICER, SECURITY_SUPERVISOR, SECURITY_ADMIN, SYSTEM_ADMIN, AUDITOR, REPORT_VIEWER
(see docs/security/rbac-matrix.md, to be produced in Milestone 3).

## 4. Functional Requirements

### 4.1 ANPR Pipeline
- **FR-001**: The system shall detect vehicles from configured camera streams.
- **FR-002**: The system shall detect registration plates within a validated vehicle detection.
- **FR-003**: The system shall perform OCR on detected plate regions.
- **FR-004**: The system shall calculate and persist a recognition confidence score, separate from any downstream database-match result.
- **FR-005**: The system shall combine evidence across multiple frames of the same vehicle session before producing a final recognition result.
- **FR-006**: The system shall normalize raw OCR text (case, whitespace, separators) while preserving the original raw OCR value.
- **FR-007**: The system shall generate alternative plate candidates when OCR confidence is ambiguous, and shall never let a database match silently raise the original OCR confidence value.
- **FR-008**: The system shall deduplicate repeated observations of the same vehicle/gate/direction within a configurable window into a single Passage Event, while retaining all underlying observations as evidence.
- **FR-009**: The system shall support configurable plate-format validation per jurisdiction/category rather than a single hard-coded regular expression, and shall mark unrecognized formats as FORMAT_UNKNOWN requiring manual review rather than auto-rejecting them.

### 4.2 Authorization Engine
- **FR-010**: The system shall evaluate vehicle authorization independently of OCR, using plate, timestamp, campus, gate, lane, direction, vehicle status, and any applicable schedule/flag.
- **FR-011**: The system shall return one of: AUTHORIZED, TEMPORARILY_AUTHORIZED, UNKNOWN, FLAGGED, EXPIRED, REVOKED, MANUAL_REVIEW_REQUIRED.
- **FR-012**: The system shall support authorization scoping by campus, gate, direction, day-of-week, and time window.
- **FR-013**: The system shall support temporary authorizations with mandatory expiry, creation reason, and creator identity — no indefinite temporary passes by default.
- **FR-014**: The system shall support flagging a vehicle with severity, reason category, creator, expiry, and instructions, and shall restrict visibility of sensitive flag detail by role.
- **FR-015**: The system shall never treat a fuzzy/near-match plate as an automatic authorization; near-matches shall be routed to manual verification.

### 4.3 Human Decision Workflow
- **FR-016**: The system shall visually and structurally distinguish "SYSTEM RESULT" from "OFFICER DECISION" at every stage.
- **FR-017**: The system shall support configurable per-gate policy: automatic-approve / officer-confirmation-required / secondary-verification-required.
- **FR-018**: For low-confidence recognition, the system shall present the plate crop, OCR result, alternative candidates, and confidence to the officer, and require one of CONFIRM / CORRECT / MANUAL CHECK / DENY / CANCEL.
- **FR-019**: Every officer override of a system recommendation shall require a reason and shall be recorded with operator identity and timestamp.
- **FR-020**: The system shall provide a manual plate-entry workflow (with mandatory reason and operator identity) for use when automated recognition is degraded or unavailable, without overwriting original camera detection data.

### 4.4 Gate Integration
- **FR-021**: The system shall model gate command flow as COMMAND_SENT → CONTROLLER_ACKNOWLEDGED → PHYSICAL_STATE_CONFIRMED, and shall report state as UNKNOWN when confirmation cannot be obtained.
- **FR-022**: The system shall enforce command idempotency, timeout, and retry limits, and shall never issue unbounded repeated commands.
- **FR-023**: The system shall expose a hardware-agnostic `GateController` interface (get_status, open, close, lock, emergency_stop, health_check) with a simulator implementation for non-production use.
- **FR-024**: Automatic Mode shall be disabled by default and shall require all of: healthy camera, healthy ANPR, healthy authorization service, healthy gate controller, healthy database, synchronized time, no active maintenance, no active emergency mode — failing any of which disables Automatic Mode for the affected gate.
- **FR-025**: Certain vehicle/gate states (flagged, unknown, low-confidence, expired, restricted gate, degraded system) shall always require manual review regardless of mode.

### 4.5 Vehicle & Visitor Management
- **FR-026**: The system shall manage authorized, temporary, fleet, contractor, visitor, and emergency vehicle categories with distinct lifecycle rules.
- **FR-027**: Visitor and contractor passes shall expire automatically and shall record host/approver and purpose.
- **FR-028**: The system shall support CSV bulk import of vehicles with validation (format, duplicates, dates, scope) and a full import audit record (accepted/rejected counts, errors, importer identity).

### 4.6 Dashboard & Operations
- **FR-029**: The system shall provide a real-time security dashboard showing live detections, authorization results, alerts, gate/camera/system health, using both color and text/iconography to convey status.
- **FR-030**: The system shall separate operational alerts (e.g., camera offline) from security alerts (e.g., flagged vehicle) in distinct queues.
- **FR-031**: The system shall group repeated detections of the same flagged vehicle into a single alert rather than issuing one alert per observation.
- **FR-032**: The system shall provide search by plate, date, gate, campus, event, and status, constrained by the searching user's role and campus/gate scope.

### 4.7 Audit, Reporting, Privacy
- **FR-033**: The system shall write an audit record for every security-sensitive action (see docs/security/threat-model.md §Audit Events) with actor, action, resource, timestamp, IP, result, and correlation IDs.
- **FR-034**: Audit records shall not be deletable by ordinary users; administrative deletion (where legally required) shall itself require elevated permission, reason, and its own audit event.
- **FR-035**: The system shall implement configurable, category-based data retention (raw images, incidents, audit logs, aggregate statistics) with automatic deletion jobs, and shall never delete records under an active legal/security hold.
- **FR-036**: The system shall provide exportable reports (CSV/PDF) that default to aggregate figures; per-vehicle historical detail shall require elevated, audited access.
- **FR-037**: The system shall support role-scoped campus/gate data boundaries such that a user cannot view another campus's data without explicit cross-campus permission.

### 4.8 Resilience
- **FR-038**: On camera loss, the system shall raise an operational alert and preserve a manual verification workflow at the affected lane.
- **FR-039**: On database or ANPR-service unavailability, the system shall never default to an "authorized" state; it shall display service-unavailable status and require manual procedure.
- **FR-040**: The system shall support edge-local buffering of events during network outage and secure, signature-validated synchronization on reconnection, with no silent event loss.

## 5. Non-Functional Requirements

- **NFR-001 Availability**: Target per-gate ANPR/authorization availability to be defined after site survey and hardware sizing; no SLA is asserted in this document.
- **NFR-002 Performance**: Vehicle/plate detection sub-second where hardware allows; authorization evaluation in milliseconds to low hundreds of ms under normal load. Final targets require measurement on selected hardware.
- **NFR-003 Security**: OWASP ASVS-aligned controls; MFA for privileged roles; server-side enforcement of all permissions; encrypted transit (TLS) and at-rest storage.
- **NFR-004 Privacy**: Purpose limitation, data minimization, configurable retention, audited image access, no external AI service use without explicit MSU approval.
- **NFR-005 Scalability**: Support multiple campuses, multiple gates/lanes/cameras per campus, and horizontal scaling of ANPR workers via message-queue-driven processing.
- **NFR-006 Maintainability**: Modular, interface-driven design (OCR, camera, gate, identity, storage, notification all pluggable) to allow vendor/engine replacement without redesign.
- **NFR-007 Auditability**: Every access decision traceable end-to-end from camera detection through officer action to gate command.
- **NFR-008 Accessibility**: Keyboard navigation, screen-reader labels, non-color status indicators, high-contrast mode.
- **NFR-009 Disaster Recovery**: Documented RPO/RTO, tested backup/restore, manual gate procedure independent of software availability.

## 6. Explicit Non-Goals

- No facial recognition or biometric identification.
- No scraping or use of external government/police/insurance/social databases.
- No indefinite/unbounded automatic gate control without phased validation and explicit MSU approval (see docs/deployment/architecture.md §Phased Rollout).
- No assumption of access to real MSU network addresses, credentials, or personal records — all such values are configuration placeholders pending authorized input.

## 7. Open Items Requiring MSU Input

- Final Zimbabwean plate-format configuration(s) and special-category formats.
- Approved identity provider (OIDC) details, if any.
- Approved SIEM/ticketing/notification providers.
- Final retention schedule (subject to MSU governance/privacy approval).
- Site-specific network, VLAN, and hardware addresses (all represented as placeholders, e.g. `<MSU_CAMERA_VLAN>`).
