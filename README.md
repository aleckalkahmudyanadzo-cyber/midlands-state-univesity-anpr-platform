\# MSU Campus ANPR \& Vehicle Access-Control Platform



Status: \*\*Early development / architecture phase.\*\* Not yet approved for

connection to real MSU cameras, gate controllers, or production data.



\# Project Purpose



A production oriented Automatic Number Plate Recognition (ANPR) and vehicle

access-control platform for Midlands State University campus security. The

system assists trained security personnel in determining whether a vehicle

approaching a gate is authorized, temporarily authorized, unknown, flagged,

expired, or revoked  it produces a \*\*recommendation\*\*, with human security

officers retaining decision authority, especially during initial deployment.



See `docs/requirements/SRS.md` for the full requirements specification.



\## Architecture



High-level architecture, component diagram, and data-flow are documented in

`docs/architecture/README.md`. Entity-relationship diagram in

`docs/architecture/ERD.md`.



Core separation of concerns:CAMERA -> ANPR -> AUTHORIZATION ENGINE -> SECURITY OFFICER -> GATE CONTROLLER -> AUDIT


\## Repository Structure
docs/ Requirements, architecture, security, and deployment docs

database/ SQL migrations (schema)

backend/ FastAPI backend application


\## Requirements



\- Python 3.11+ (developed against 3.14)

\- PostgreSQL 16+ (developed against 18)

\- Git



\## Installation (Development)



```bash

\# 1. Clone the repository

git clone https://github.com/aleckalkahmudyanadzo-cyber/midlands-state-univesity-anpr-platform.git

cd midlands-state-univesity-anpr-platform



\# 2. Create the database

createdb -U postgres anpr\_dev



\# 3. Load the schema

psql -U postgres -d anpr\_dev -f database/migrations/0001\_initial\_schema.sql



\# 4. Set up the backend

cd backend

python -m venv venv

venv\\Scripts\\activate        # Windows

pip install -r requirements.txt



\# 5. Configure environment

\# Create backend/.env with:

\#   DATABASE\_URL=postgresql://postgres:<password>@localhost:5432/anpr\_dev

\#   JWT\_SECRET=<a long random string>



\# 6. Run the server

uvicorn app.main:app --reload

```



Then visit `http://127.0.0.1:8000/health/db` to confirm the API is connected

to the database.



\## Security \& Privacy



This project follows privacy-by-design and security-by-design principles —

see `docs/security/threat-model.md`. No real camera credentials, gate

controller addresses, student/staff records, or production secrets are

ever committed to this repository; all such values are configuration

placeholders pending authorized input from MSU's IT and security teams.



\## Deployment



See `docs/deployment/architecture.md` for network zoning, phased rollout

plan, and information MSU must supply before go-live.



\## Status / Roadmap



\- \[x] Requirements specification, architecture, threat model, ERD

\- \[x] Initial database schema

\- \[x] FastAPI backend skeleton with database connectivity

\- \[ ] Authentication \& RBAC

\- \[ ] Vehicle \& authorization management

\- \[ ] ANPR pipeline

\- \[ ] Gate integration abstraction + simulator

\- \[ ] Audit logging

\- \[ ] Frontend security dashboard



\## License



To be determined by MSU.

