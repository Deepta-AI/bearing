# Threat model: filedrop

Last reviewed 2026-07-28, before v1.3.0. Status: `implemented` means the
mitigation is in the code; `planned` means it is not built yet.

| Id | Threat | Component | Mitigation | Where | Status |
| --- | --- | --- | --- | --- | --- |
| T-01 | A user reads another tenant's file | files | Every file handler loads the file and checks `TenantID` against the session's tenant before returning anything | internal/files/handler.go | implemented |
| T-02 | An attacker forges a session cookie for any user | auth | Cookie signed with HMAC-SHA256 under `SESSION_SECRET`, taken from the Kubernetes Secret `filedrop-secrets`; no default | internal/config/config.go, internal/auth/session.go | implemented |
| T-03 | Credential stuffing against `POST /login` | auth | 10 attempts per IP and per email per minute, then 429 | internal/auth/login.go | planned |
| T-04 | A share link is guessed, or a leaked link works forever | share | 128-bit random tokens; links expire after 7 days | internal/share/links.go | implemented |
| T-05 | Stored XSS through an uploaded HTML or SVG file | files | Files are served as attachments with `nosniff`, never inline | internal/files/handler.go | implemented |
| T-06 | Third-party API keys leak from the repository | deploy | Keys live only in Kubernetes Secrets, mounted as env | deploy/k8s | implemented |
