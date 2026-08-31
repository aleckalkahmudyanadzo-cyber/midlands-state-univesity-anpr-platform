# Data Model — Entity Relationship Diagram

Status: DRAFT. Field lists are illustrative; authoritative definitions are in
`database/migrations/0001_initial_schema.sql`.

```mermaid
erDiagram
    UNIVERSITIES ||--o{ CAMPUSES : has
    CAMPUSES ||--o{ GATES : has
    GATES ||--o{ LANES : has
    LANES ||--o{ CAMERAS : has
    CAMERAS ||--o{ DETECTIONS : produces

    USERS ||--o{ USER_CAMPUS_ROLES : assigned
    ROLES ||--o{ USER_CAMPUS_ROLES : grants
    ROLES ||--o{ ROLE_PERMISSIONS : includes
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : included_in

    VEHICLES ||--o{ VEHICLE_AUTHORIZATIONS : has
    VEHICLES ||--o{ VEHICLE_FLAGS : may_have
    VEHICLES ||--o{ VISITOR_PASSES : may_have
    VEHICLES ||--o{ PASSAGE_EVENTS : appears_in

    DETECTIONS ||--o{ PLATE_OBSERVATIONS : yields
    PLATE_OBSERVATIONS }o--|| PASSAGE_EVENTS : aggregated_into
    PASSAGE_EVENTS ||--o| ACCESS_DECISIONS : results_in
    ACCESS_DECISIONS ||--o{ GATE_COMMANDS : triggers
    GATES ||--o{ GATE_COMMANDS : receives
    GATE_COMMANDS ||--o{ GATE_EVENTS : produces

    PASSAGE_EVENTS ||--o{ SECURITY_ALERTS : may_raise
    VEHICLE_FLAGS ||--o{ SECURITY_ALERTS : may_raise
    SECURITY_ALERTS }o--|| INCIDENTS : may_link

    USERS ||--o{ AUDIT_LOGS : performs
    USERS ||--o{ ACCESS_DECISIONS : decides
    USERS ||--o{ VEHICLE_AUTHORIZATIONS : approves

    DETECTIONS ||--o{ ATTACHMENTS : has
    INCIDENTS ||--o{ ATTACHMENTS : has

    UNIVERSITIES {
        uuid id PK
        text name
    }
    CAMPUSES {
        uuid id PK
        uuid university_id FK
        text name
        text code
    }
    GATES {
        uuid id PK
        uuid campus_id FK
        text name
        text status
    }
    LANES {
        uuid id PK
        uuid gate_id FK
        text direction
        text name
    }
    CAMERAS {
        uuid id PK
        uuid lane_id FK
        text stream_ref
        text status
    }
    VEHICLES {
        uuid id PK
        text registration_number
        text normalized_registration_number
        text vehicle_type
        text owner_category
        text owner_reference
        text status
    }
    VEHICLE_AUTHORIZATIONS {
        uuid id PK
        uuid vehicle_id FK
        text authorization_type
        uuid campus_id FK
        uuid gate_id FK
        text direction
        timestamptz valid_from
        timestamptz valid_until
        text days_of_week
        time start_time
        time end_time
        text status
        uuid approved_by FK
    }
    VEHICLE_FLAGS {
        uuid id PK
        uuid vehicle_id FK
        text severity
        text reason_category
        uuid created_by FK
        timestamptz expires_at
        text instructions
    }
    VISITOR_PASSES {
        uuid id PK
        uuid vehicle_id FK
        text visitor_name
        text host_reference
        timestamptz valid_from
        timestamptz valid_until
        uuid approved_by FK
    }
    DETECTIONS {
        uuid id PK
        uuid camera_id FK
        uuid gate_id FK
        uuid lane_id FK
        timestamptz detected_at
        text vehicle_tracking_id
        text image_reference
        text processing_version
    }
    PLATE_OBSERVATIONS {
        uuid id PK
        uuid detection_id FK
        text raw_plate_text
        text normalized_plate_text
        numeric ocr_confidence
        numeric vehicle_confidence
        numeric plate_confidence
    }
    PASSAGE_EVENTS {
        uuid id PK
        text vehicle_session_id
        uuid vehicle_id FK
        text final_plate_text
        numeric final_confidence
        uuid camera_id FK
        uuid gate_id FK
        uuid lane_id FK
        text direction
        timestamptz first_seen
        timestamptz last_seen
        text authorization_result
    }
    ACCESS_DECISIONS {
        uuid id PK
        uuid passage_event_id FK
        text decision
        text reason
        uuid officer_id FK
        timestamptz timestamp
        text system_recommendation
        boolean officer_override
        text override_reason
    }
    GATE_COMMANDS {
        uuid id PK
        uuid access_decision_id FK
        uuid gate_id FK
        text command
        text command_id
        text status
        timestamptz sent_at
        timestamptz acknowledged_at
    }
    GATE_EVENTS {
        uuid id PK
        uuid gate_command_id FK
        text physical_state
        timestamptz observed_at
    }
    SECURITY_ALERTS {
        uuid id PK
        uuid passage_event_id FK
        uuid vehicle_flag_id FK
        text severity
        text status
        uuid assigned_to FK
        uuid incident_id FK
    }
    INCIDENTS {
        uuid id PK
        text type
        text severity
        text status
        uuid assigned_to FK
        text resolution
    }
    USERS {
        uuid id PK
        text username
        text password_hash
        boolean mfa_enabled
        text status
    }
    ROLES {
        uuid id PK
        text name
    }
    PERMISSIONS {
        uuid id PK
        text code
    }
    ROLE_PERMISSIONS {
        uuid role_id FK
        uuid permission_id FK
    }
    USER_CAMPUS_ROLES {
        uuid user_id FK
        uuid campus_id FK
        uuid role_id FK
        uuid gate_id FK
    }
    AUDIT_LOGS {
        uuid id PK
        timestamptz timestamp
        uuid actor_id FK
        text action
        text resource_type
        uuid resource_id
        text ip_address
        text result
        text request_id
    }
    ATTACHMENTS {
        uuid id PK
        uuid detection_id FK
        uuid incident_id FK
        text object_reference
        text sha256_hash
    }
```

## Notes

- `normalized_registration_number` is indexed on `vehicles` and `plate_observations`
  for fast lookup; see migration for exact index list.
- `owner_reference` is an opaque pointer into MSU's authoritative student/staff
  system — this platform does not duplicate personal records (SRS FR-026, §7).
- Raw OCR text is never overwritten; `plate_observations` is append-only per
  detection frame, and `passage_events.final_plate_text` records only the
  aggregated result, with full observation history retained for audit.
- `audit_logs` is designed as append-only (no UPDATE/DELETE grants for the
  application role — see migration for role/grant definitions).
