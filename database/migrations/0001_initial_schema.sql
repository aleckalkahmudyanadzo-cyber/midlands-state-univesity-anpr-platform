-- 0001_initial_schema.sql
-- MSU ANPR & Vehicle Access-Control Platform
-- Initial schema. Review with DBA before production use.
-- Run as a migration (Alembic) owner role, never as the application role.

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

-- ============================================================
-- Organizational hierarchy
-- ============================================================

CREATE TABLE universities (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE campuses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id   UUID NOT NULL REFERENCES universities(id),
    name            TEXT NOT NULL,
    code            TEXT NOT NULL UNIQUE,
    timezone        TEXT NOT NULL DEFAULT 'Africa/Harare',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE gates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campus_id       UUID NOT NULL REFERENCES campuses(id),
    name            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','MAINTENANCE','DISABLED')),
    automatic_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (campus_id, name)
);

CREATE TABLE lanes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gate_id         UUID NOT NULL REFERENCES gates(id),
    name            TEXT NOT NULL,
    direction       TEXT NOT NULL CHECK (direction IN ('ENTRY','EXIT','BOTH')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (gate_id, name)
);

CREATE TABLE cameras (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lane_id         UUID NOT NULL REFERENCES lanes(id),
    label           TEXT NOT NULL,
    stream_ref      TEXT NOT NULL, -- placeholder/secret-manager reference, never a literal credentialed URL
    status          TEXT NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','MAINTENANCE','OFFLINE','DISABLED')),
    calibration     JSONB, -- detection zone, plate zone, min/max vehicle size, etc.
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Identity, roles, permissions
-- ============================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        TEXT NOT NULL UNIQUE,
    password_hash   TEXT, -- Argon2id; NULL if identity is federated via OIDC
    mfa_enabled     BOOLEAN NOT NULL DEFAULT FALSE,
    status          TEXT NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','DISABLED','LOCKED')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE roles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE
        CHECK (name IN ('SECURITY_OFFICER','SECURITY_SUPERVISOR','SECURITY_ADMIN',
                         'SYSTEM_ADMIN','AUDITOR','REPORT_VIEWER'))
);

CREATE TABLE permissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE -- e.g. 'vehicle.read', 'access.approve'
);

CREATE TABLE role_permissions (
    role_id         UUID NOT NULL REFERENCES roles(id),
    permission_id   UUID NOT NULL REFERENCES permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

-- A user's role can be scoped to a campus and, optionally, a specific gate.
CREATE TABLE user_campus_roles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    campus_id       UUID NOT NULL REFERENCES campuses(id),
    gate_id         UUID REFERENCES gates(id), -- NULL = all gates on campus
    role_id         UUID NOT NULL REFERENCES roles(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, campus_id, gate_id, role_id)
);

-- ============================================================
-- Vehicles, authorizations, visitors, flags
-- ============================================================

CREATE TABLE vehicles (
    id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_number             TEXT NOT NULL,
    normalized_registration_number  TEXT NOT NULL,
    vehicle_type                    TEXT,
    make                            TEXT,
    model                           TEXT,
    colour                          TEXT,
    owner_category                  TEXT
        CHECK (owner_category IN ('STUDENT','STAFF','CONTRACTOR','VISITOR','FLEET','EMERGENCY','UNKNOWN')),
    owner_reference                 TEXT, -- opaque pointer into authoritative MSU system; not a personal record
    status                          TEXT NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','ARCHIVED')),
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at                      TIMESTAMPTZ
);

CREATE INDEX idx_vehicles_normalized_plate ON vehicles (normalized_registration_number);

CREATE TABLE vehicle_authorizations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id          UUID NOT NULL REFERENCES vehicles(id),
    authorization_type  TEXT NOT NULL
        CHECK (authorization_type IN ('PERMANENT','TEMPORARY','VISITOR','CONTRACTOR','EVENT','FLEET','EMERGENCY')),
    campus_id           UUID REFERENCES campuses(id), -- NULL = all campuses (rare; requires elevated approval)
    gate_id             UUID REFERENCES gates(id),    -- NULL = all gates on campus
    direction           TEXT NOT NULL DEFAULT 'BOTH' CHECK (direction IN ('ENTRY','EXIT','BOTH')),
    valid_from          TIMESTAMPTZ NOT NULL,
    valid_until         TIMESTAMPTZ NOT NULL,
    days_of_week        TEXT, -- e.g. 'MON,TUE,WED,THU,FRI'
    start_time          TIME,
    end_time            TIME,
    status              TEXT NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING','ACTIVE','EXPIRED','REVOKED','SUSPENDED')),
    reason              TEXT,
    approved_by         UUID REFERENCES users(id),
    created_by          UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (valid_until > valid_from)
);

CREATE INDEX idx_vehicle_auth_status ON vehicle_authorizations (status);
CREATE INDEX idx_vehicle_auth_vehicle ON vehicle_authorizations (vehicle_id);

CREATE TABLE visitor_passes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_reference  TEXT NOT NULL UNIQUE, -- e.g. VIS-2026-000341
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    visitor_name    TEXT NOT NULL,
    host_reference  TEXT NOT NULL,
    visit_purpose   TEXT,
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    approved_by     UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (valid_until > valid_from)
);

CREATE TABLE vehicle_flags (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id          UUID NOT NULL REFERENCES vehicles(id),
    status              TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','EXPIRED','REMOVED')),
    severity            TEXT NOT NULL CHECK (severity IN ('INFO','WARNING','HIGH','CRITICAL')),
    reason_category     TEXT NOT NULL,
    instructions        TEXT, -- procedural guidance only, never physical-confrontation instructions
    incident_reference  UUID,
    created_by          UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ,
    removed_by          UUID REFERENCES users(id),
    removed_at          TIMESTAMPTZ
);

CREATE INDEX idx_vehicle_flags_status ON vehicle_flags (status);

-- ============================================================
-- ANPR pipeline: detections, observations, passage events
-- ============================================================

CREATE TABLE detections (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_uuid              UUID NOT NULL DEFAULT gen_random_uuid(),
    camera_id               UUID NOT NULL REFERENCES cameras(id),
    gate_id                 UUID NOT NULL REFERENCES gates(id),
    lane_id                 UUID NOT NULL REFERENCES lanes(id),
    detected_at             TIMESTAMPTZ NOT NULL,
    vehicle_tracking_id     TEXT NOT NULL, -- e.g. VS-2026-000001
    vehicle_confidence      NUMERIC(5,2),
    image_reference         TEXT, -- object storage reference, not a public URL
    processing_version      TEXT NOT NULL, -- model+ocr+pipeline version string
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_detections_detected_at ON detections (detected_at);
CREATE INDEX idx_detections_gate ON detections (gate_id);
CREATE INDEX idx_detections_tracking ON detections (vehicle_tracking_id);

CREATE TABLE plate_observations (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    detection_id            UUID NOT NULL REFERENCES detections(id),
    raw_plate_text          TEXT NOT NULL,       -- never overwritten
    normalized_plate_text   TEXT NOT NULL,
    ocr_confidence          NUMERIC(5,2) NOT NULL,
    plate_confidence        NUMERIC(5,2),
    alternative_candidates  JSONB, -- [{text, confidence}, ...]
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_plate_obs_normalized ON plate_observations (normalized_plate_text);
CREATE INDEX idx_plate_obs_detection ON plate_observations (detection_id);

CREATE TABLE passage_events (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_session_id      TEXT NOT NULL UNIQUE, -- e.g. VS-2026-000001
    vehicle_id              UUID REFERENCES vehicles(id), -- NULL until/unless matched
    final_plate_text        TEXT NOT NULL,
    final_confidence        NUMERIC(5,2) NOT NULL,
    camera_id               UUID NOT NULL REFERENCES cameras(id),
    gate_id                 UUID NOT NULL REFERENCES gates(id),
    lane_id                 UUID NOT NULL REFERENCES lanes(id),
    direction               TEXT NOT NULL CHECK (direction IN ('ENTRY','EXIT')),
    first_seen              TIMESTAMPTZ NOT NULL,
    last_seen               TIMESTAMPTZ NOT NULL,
    observation_count       INTEGER NOT NULL DEFAULT 1,
    authorization_result    TEXT NOT NULL DEFAULT 'MANUAL_REVIEW_REQUIRED'
        CHECK (authorization_result IN
            ('AUTHORIZED','TEMPORARILY_AUTHORIZED','UNKNOWN','FLAGGED',
             'EXPIRED','REVOKED','MANUAL_REVIEW_REQUIRED')),
    authorization_policy_version TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_passage_events_plate ON passage_events (final_plate_text);
CREATE INDEX idx_passage_events_gate_time ON passage_events (gate_id, first_seen);

-- Links a passage event back to every underlying observation (evidence retained).
CREATE TABLE passage_event_observations (
    passage_event_id    UUID NOT NULL REFERENCES passage_events(id),
    plate_observation_id UUID NOT NULL REFERENCES plate_observations(id),
    PRIMARY KEY (passage_event_id, plate_observation_id)
);

-- ============================================================
-- Access decisions and gate commands
-- ============================================================

CREATE TABLE access_decisions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passage_event_id        UUID NOT NULL REFERENCES passage_events(id),
    decision                TEXT NOT NULL CHECK (decision IN ('APPROVE','DENY','MANUAL_REVIEW')),
    reason                  TEXT NOT NULL,
    system_recommendation   TEXT NOT NULL,
    officer_id              UUID REFERENCES users(id), -- NULL only if fully automatic mode (rare, approved case)
    officer_override        BOOLEAN NOT NULL DEFAULT FALSE,
    override_reason         TEXT,
    timestamp               TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (officer_override = FALSE OR override_reason IS NOT NULL)
);

CREATE TABLE gate_commands (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    command_id          TEXT NOT NULL UNIQUE, -- idempotency key
    access_decision_id  UUID REFERENCES access_decisions(id),
    gate_id             UUID NOT NULL REFERENCES gates(id),
    command              TEXT NOT NULL CHECK (command IN ('OPEN','CLOSE','LOCK','EMERGENCY_STOP')),
    status               TEXT NOT NULL DEFAULT 'SENT'
                             CHECK (status IN ('SENT','ACKNOWLEDGED','TIMEOUT','FAILED')),
    sent_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged_at      TIMESTAMPTZ,
    retry_count          INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE gate_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gate_command_id     UUID REFERENCES gate_commands(id),
    gate_id             UUID NOT NULL REFERENCES gates(id),
    physical_state      TEXT NOT NULL CHECK (physical_state IN ('OPEN','CLOSED','UNKNOWN','FAULT')),
    observed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    source               TEXT -- e.g. 'sensor', 'controller_ack', 'manual'
);

-- ============================================================
-- Alerts and incidents
-- ============================================================

CREATE TABLE incidents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_type   TEXT NOT NULL,
    severity        TEXT NOT NULL CHECK (severity IN ('INFO','WARNING','HIGH','CRITICAL')),
    description     TEXT,
    status          TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','ASSIGNED','RESOLVED','CLOSED')),
    assigned_to     UUID REFERENCES users(id),
    resolution      TEXT,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at     TIMESTAMPTZ
);

CREATE TABLE security_alerts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passage_event_id     UUID REFERENCES passage_events(id),
    vehicle_flag_id      UUID REFERENCES vehicle_flags(id),
    severity             TEXT NOT NULL CHECK (severity IN ('INFO','WARNING','HIGH','CRITICAL')),
    alert_type            TEXT NOT NULL CHECK (alert_type IN ('OPERATIONAL','SECURITY')),
    status                TEXT NOT NULL DEFAULT 'OPEN'
                              CHECK (status IN ('OPEN','ACKNOWLEDGED','RESOLVED','ESCALATED')),
    grouped_observation_count INTEGER NOT NULL DEFAULT 1,
    assigned_to           UUID REFERENCES users(id),
    incident_id           UUID REFERENCES incidents(id),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged_by       UUID REFERENCES users(id),
    acknowledged_at       TIMESTAMPTZ,
    resolution_category   TEXT
);

CREATE INDEX idx_security_alerts_status ON security_alerts (status);

-- ============================================================
-- Audit (append-only)
-- ============================================================

CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "timestamp"     TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor_id        UUID REFERENCES users(id),
    action          TEXT NOT NULL,
    resource_type   TEXT NOT NULL,
    resource_id     UUID,
    ip_address      INET,
    user_agent      TEXT,
    result          TEXT NOT NULL CHECK (result IN ('SUCCESS','FAILURE','DENIED')),
    metadata        JSONB,
    request_id      TEXT
);

CREATE INDEX idx_audit_logs_actor ON audit_logs (actor_id);
CREATE INDEX idx_audit_logs_action ON audit_logs (action);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs ("timestamp");

-- ============================================================
-- Misc: notifications, settings, retention, attachments
-- ============================================================

CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id    UUID REFERENCES users(id),
    channel         TEXT NOT NULL CHECK (channel IN ('DASHBOARD','EMAIL','SMS','OTHER')),
    subject         TEXT,
    body            TEXT,
    sent_at         TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SENT','FAILED'))
);

CREATE TABLE system_settings (
    key             TEXT PRIMARY KEY,
    value           JSONB NOT NULL,
    updated_by      UUID REFERENCES users(id),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE retention_policies (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category        TEXT NOT NULL UNIQUE, -- e.g. 'raw_images', 'audit_logs', 'incidents'
    retention_days  INTEGER NOT NULL,
    legal_hold      BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by      UUID REFERENCES users(id),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE attachments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    detection_id        UUID REFERENCES detections(id),
    incident_id         UUID REFERENCES incidents(id),
    object_reference     TEXT NOT NULL,
    sha256_hash          TEXT NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Database roles (least privilege) — placeholders for actual
-- passwords/usernames, to be set via secrets manager.
-- ============================================================

-- Application role: no DDL rights, no superuser, restricted grants only.
-- CREATE ROLE anpr_app_role LOGIN PASSWORD '<SECRET_MANAGER_PLACEHOLDER>';
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO anpr_app_role;
-- REVOKE DELETE ON audit_logs FROM anpr_app_role; -- append-only enforcement
-- REVOKE UPDATE ON audit_logs FROM anpr_app_role;

-- Read-only reporting role:
-- CREATE ROLE anpr_reporting_role LOGIN PASSWORD '<SECRET_MANAGER_PLACEHOLDER>';
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO anpr_reporting_role;

-- Migration role (schema management) is expected to be a separate, more
-- privileged role used only by the CI/CD migration step, never by the running application.
