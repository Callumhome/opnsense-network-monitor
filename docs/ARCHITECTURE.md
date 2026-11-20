# OPNsense Network Manager 3.0 — Architecture

## Product direction

A local-first Android control centre for OPNsense. The Android client talks only to the user's Proxmox-hosted backend. The backend talks to OPNsense through its documented API. The app is inspired by OPN Admin's practical management workflow, with a redesigned mobile-first interface.

**Project choices**
- Product: OPNsense Network Manager 3.0
- Client: Flutter for Android
- Backend: Python + FastAPI
- Persistence: SQLite initially (existing deployment is a small single-user home-lab service); keep repository/service boundaries portable to PostgreSQL later
- Deployment target: existing dedicated Proxmox LXC, currently reported as CT 105 at 192.168.1.160:8000
- Firewall: OPNsense at 192.168.1.254
- Operation: local network only; no cloud dependency
- Control model: broad management coverage, with explicit review and confirmation before every configuration-changing or disruptive operation

## High-level topology

```text
Flutter Android app
   | HTTPS / authenticated app API
   v
FastAPI backend on Proxmox (CT 105)
   |-- app database: device aliases, history, audit, pending changes
   |-- discovery/status workers
   |-- OPNsense API adapter + capability registry
   |-- change planner / validator / backup / apply / verify
   v
OPNsense API (key + secret held only by backend)
   |-- core and plugin APIs available on this installed version
   v
Interfaces, DHCP, ARP/neighbours, firewall, routing, VPN, services, system
```

The Android APK must never contain OPNsense API credentials. The backend must not expose a generic arbitrary-URL proxy or arbitrary shell execution endpoint.

## Main backend modules

- `app/api`: versioned client-facing REST endpoints and authentication.
- `app/integrations/opnsense`: authenticated HTTP client, TLS verification, endpoint adapters and version detection.
- `app/capabilities`: feature registry describing read/write/apply support and availability on the installed OPNsense version/plugins.
- `app/devices`: DHCP leases, ARP/neighbour observations, ping checks, identity and user-defined aliases.
- `app/networks`: interfaces, VLANs, subnets, gateways and device-to-interface association.
- `app/changes`: proposed change plans, validation, confirmation, backup, apply, verification and recovery guidance.
- `app/audit`: append-only record of who changed what, when, request payload summary, result and OPNsense response metadata.
- `app/workers`: scheduled polling and history collection.
- `app/db`: migrations and repositories.

## Device identity and presence

A device's durable identity is based primarily on MAC address, with interface/VLAN context retained so the same MAC observed on different networks can be investigated rather than silently misclassified. Store user aliases separately from DHCP hostnames and reverse-DNS names.

Keep these concepts separate:
- DHCP lease validity: an address allocation, not proof the device is awake.
- Presence observations: ARP/neighbour, ping, interface/host-discovery data and recent traffic where available.
- Last seen: timestamp of the most recent positive observation.
- Display state: Online, Sleeping/Unreachable, Offline, or Unknown, derived from configurable evidence windows.

Never mark a device online solely because it has an unexpired DHCP lease. Never delete reservations as part of routine stale-lease cleanup. VLAN classification should prefer OPNsense interface/VLAN data and observed interface context, using subnet matching as a fallback and reporting ambiguity.

Custom device names and notes live in the app database and survive DHCP renewals and IP changes.

## Change safety model

All write operations follow a common workflow:

1. Read current state from OPNsense.
2. Build a human-readable proposed change with before/after values and affected interfaces/devices.
3. Validate fields, dependencies, API capability and risk.
4. Show the proposal to the user in the app; no write occurs until explicit confirmation.
5. Where supported, export/save a configuration backup or snapshot before applying.
6. Submit the specific documented API operation.
7. Apply/reconfigure only when required by that API.
8. Re-read state and verify the intended result.
9. Record success/failure and recovery instructions in the audit log.

High-risk operations (WAN/LAN changes, VLAN/interface assignments, DHCP scope changes, firewall rule changes that may cut off access, routing, VPN, firmware, reboot and service restarts) require a stronger warning and a second confirmation. The app must warn if a change could sever the backend's path to OPNsense. No automatic rollback is promised unless the operation has a tested rollback path.

## Security

- Create a dedicated OPNsense API user/key for this backend, with only the privileges needed for enabled capabilities. Expand privileges deliberately as modules are added.
- Store key/secret in a root-readable backend environment/secret file; never return them to the client or log them.
- Verify OPNsense TLS certificates; do not ship `verify=False` in production.
- Authenticate Android clients to the backend; use HTTPS on the LAN and support credential rotation.
- Keep CORS, rate limits, request validation and audit logging enabled.
- No public internet exposure by default. Tailscale access can be considered as a separate secured transport, not a requirement.
- No generic command execution or arbitrary OPNsense endpoint forwarding from the app.

## Capability coverage

Build a capability registry rather than assuming every OPNsense page has a stable public API. The official API reference lists core and plugin modules, but endpoint availability and permissions depend on the installed OPNsense version and installed plugins. Some legacy/file-based features are not covered by the MVC API. Each feature must report one of:
- Supported: read and write tested
- Read-only: reliable read path, no safe write path
- Partial: some operations supported
- Unavailable: API/plugin/version/permission missing

Initial domains to inventory: system health and firmware; interfaces and VLANs; DHCP (Kea/ISC/Dnsmasq as installed); DNS/Unbound; firewall rules, aliases, NAT and states; gateways/routes; VPN (WireGuard/OpenVPN/IPsec); certificates/trust; services/plugins; logs/diagnostics; users/API privileges; backups/configuration.

## Client information architecture

Bottom navigation:
1. Overview
2. Devices
3. Network
4. Firewall
5. System

Device detail includes alias editing, notes, IP/MAC, actual interface/VLAN, DHCP reservation, presence history, last-seen, and safe block/unblock actions. Blocking must create or update a persistent firewall policy (or another verified persistent access-control mechanism); killing states alone is not considered a durable block.

Every mutating screen uses a consistent review screen showing the exact operation, target, before/after values, expected impact, backup status and confirmation action.

## Delivery phases

### Phase 0 — Inventory and baseline
- Inspect current backend source, database and API contract in CT 105.
- Inspect Flutter source and current repository tree.
- Record OPNsense version, enabled DHCP service, installed plugins and API privileges.
- Export a known-good OPNsense configuration backup.
- Do not change live firewall configuration.

### Phase 1 — Backend foundation
- Introduce versioned API, authentication, migrations, structured logs and audit records.
- Add OPNsense connectivity/version/capability discovery.
- Keep compatibility adapters for the existing app endpoints during migration.

### Phase 2 — Read-only inventory
- Interfaces/VLANs, DHCP leases/reservations, neighbours, gateways, firewall rules/states and system health.
- Device identity, aliases, presence engine and history.
- Validate counts and device/interface mapping against OPNsense UI and OPN Admin.

### Phase 3 — Controlled writes
- Device rename and notes (app-local).
- DHCP reservation management.
- Persistent device block/unblock.
- Firewall aliases and rules, with review/apply/verify workflow.
- Add further write domains only after endpoint-specific tests.

### Phase 4 — Full management domains
- Interfaces/VLANs, routing, VPN, services, system, backups and firmware where API support and safe recovery are established.

### Phase 5 — Flutter redesign and release
- Implement the new mobile-first UI against the versioned backend.
- Offline/error/loading states, live refresh, search, filters, notifications and accessibility.
- Integration tests, release builds and migration documentation.

## Existing project context to preserve

- GitHub: `Callumhome/opnsense-network-monitor`
- Flutter project on the user's development host: `/root/dhcp-app/opnsense_network_monitor`
- Existing backend deployment reported at Proxmox CT 105, `192.168.1.160:8000`, with `/docs`
- Existing backend routes reported: `/`, `/api/health`, `/api/reservations`, `/api/devices`, `/api/alerts`, `/api/offline`, and later `/api/vlans`
- OPNsense LAN address: `192.168.1.254`
- Current operational LAN remains `192.168.1.0/24`. Proposed VLAN networks are design targets, not proof that those VLANs are active. Do not change the live network during the initial rebuild.

## First implementation gate

Do not deploy code or alter the firewall until the current backend and Flutter source have been inspected and a configuration backup has been confirmed. The immediate next task is to collect the backend source tree and Flutter source tree, then produce a verified endpoint/capability inventory for the actual OPNsense installation.
