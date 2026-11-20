# OPNsense Network Manager 3.0 — Backend

Fresh backend foundation for deployment on the existing Proxmox CT105.

## Safety rules

- This service is separate from the legacy Network Monitor backend.
- Initial deployment uses port 8001; do not replace or stop the existing service yet.
- Do not put OPNsense API credentials in the Android app or Git.
- Do not expose this API to the public internet.
- The first milestone is read-only inventory. No firewall configuration writes are enabled.
- Before later write operations, implement review, explicit confirmation, backup, apply, verification and audit logging.

## Bootstrap on CT105

Create a dedicated directory such as `/opt/opnsense-network-manager`, copy this backend directory there, create a Python virtual environment, install `requirements.txt`, and create a private `.env` from `.env.example`.

Generate a strong random `APP_API_TOKEN` and protect `.env` with owner-only permissions. Do not use the example token.

Run initially for a local smoke test:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

Health check: `GET /api/health`.

Authenticated status check: `GET /api/v1/status` with `Authorization: Bearer <APP_API_TOKEN>`.

This is a bootstrap scaffold, not yet a complete OPNsense integration. Configure the OPNsense API adapter only after checking the installed OPNsense version, API permissions, TLS certificate and available endpoints.
