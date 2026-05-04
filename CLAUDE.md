# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a building intercom system for a residential building (23 apartments, 2 entrances) built on a self-hosted Docker stack. The system replaces an old analog домофон with a modern IP-based solution supporting video, RFID access, SIP calls, and mobile app integration.

## Stack

All services run via `docker-compose.yml` with `network_mode: host` throughout — all containers share the host network, so inter-service communication uses `127.0.0.1`.

| Service | Image | Port | Role |
|---|---|---|---|
| go2rtc | alexxit/go2rtc | 1984 (API), 8554 (RTSP), 8555 (WebRTC) | Camera stream proxy |
| mosquitto | eclipse-mosquitto | 1883 | MQTT broker |
| frigate | blakeblackshear/frigate:stable | 5000 | NVR, motion/person detection |
| homeassistant | home-assistant/home-assistant:stable | 8123 | Automation hub, mobile app |
| asterisk | andrius/asterisk:18 | 5060 (SIP), 5038 (AMI), 10000-10100 (RTP) | SIP PBX |

## Common Commands

```bash
# Start all services
docker compose up -d

# Start a single service
docker compose up -d asterisk

# View logs
docker compose logs -f asterisk

# Reload Asterisk dialplan without restart
docker exec asterisk asterisk -rx "dialplan reload"

# Reload all Asterisk config without restart
docker exec asterisk asterisk -rx "core reload"

# Check Asterisk SIP endpoints
docker exec asterisk asterisk -rx "pjsip show endpoints"

# Test HA webhook (simulates doorbell press)
curl -s -X POST http://127.0.0.1:8123/api/webhook/doorbell_south \
  -H "Content-Type: application/json" \
  -d '{"apartment":"107","camera":"south_panel"}'
```

## Architecture

### Call Flow (doorbell → phone)
1. Visitor presses button on **GDS3710** entrance panel → GDS3710 initiates SIP INVITE to Asterisk
2. **Asterisk** (`extensions.conf`, context `building`) matches dialed apartment number (`_1XX` pattern)
3. Before ringing, Asterisk uses `CURL()` to POST to HA webhook `doorbell_south`
4. **Home Assistant** automation fires → push notification to resident's phone with camera snapshot + "Open Door" action
5. Asterisk dials the apartment SIP extension (ATAs for analog handsets, or SIP app directly)

### Door Open Flow
- Resident taps "Open Door" in push notification → HA fires `mobile_app_notification_action` event → `rest_command.open_south_door` calls GDS3710 HTTP API

### Camera Pipeline
- go2rtc pulls RTSP streams from cameras and entrance panels, exposes them on port 8554
- Frigate connects to go2rtc via `rtsp://127.0.0.1:8554/<stream_name>` — never directly to cameras
- HA uses Frigate integration (installed via HACS) for camera entities and snapshots

### Deployment Plan
- **Phase 1**: South entrance only (greenfield, no legacy) — currently in dev/test
- **Phase 2**: North entrance integration (existing analog домофон still operational on north side)
- **Phase 3**: Per-apartment app endpoints; analog handsets kept via Grandstream GXW4224 (24-port FXS gateway in basement cabinet)

## Network

Building network will be `192.168.1.x`. Device IP assignments:

| Device | IP |
|---|---|
| Server | 192.168.1.10 |
| South GDS3710 panel | 192.168.1.20 |
| South cam 1 (Hikvision) | 192.168.1.31 |
| South cam 2 (Hikvision) | 192.168.1.32 |

Dev machine is currently on `192.168.70.x`. The gitignored `.env` holds the active IPs (`CAM1_HOST=192.168.70.160` in dev); `.env.example` has production placeholders.

## Environment variables (`.env`)

All per-deployment values live in `.env`. The rule: if it changes between dev and prod, or differs per install — it goes in `.env`. If it's a stack constant (e.g. `127.0.0.1`, port numbers) — it stays inline.

**Hosts:**
- `PANEL_HOST` — GDS3710 IP (e.g. `192.168.1.20`)
- `CAM1_HOST`, `CAM2_HOST` — Hikvision camera IPs

**Usernames:**
- `PANEL_USER` — GDS3710 admin username
- `CAM_USER` — shared username for all Hikvision cams

**Passwords:**
- `PANEL_PASSWORD` — GDS3710 admin password (go2rtc, pjsip.conf, door-open URL)
- `CAM1_PASSWORD`, `CAM2_PASSWORD` — Hikvision RTSP passwords
- `TEST_PASSWORD` — SIP extension 9000 (dev only, remove before production)
- `AMI_PASSWORD` — Asterisk Manager Interface password (used by Home Assistant)

**Home Assistant:**
- `HA_NOTIFY_TARGET` — mobile app notify service (e.g. `notify.mobile_app_sm_a536b`)
- `OPEN_SOUTH_DOOR_URL` — assembled by `docker-compose.yml` from `PANEL_HOST`/`PANEL_USER`/`PANEL_PASSWORD`; do not set manually

## Asterisk Extensions

- `_1XX` — apartment extensions 101–123, routed from entrance panel
- `9000` — test/dev extension (SIP softphone, e.g. baresip)
- `south_panel` — GDS3710 south entrance SIP peer

## HA Automations

Stored in `homeassistant/automations.yaml` (included via `configuration.yaml`). After editing the file directly, reload via HA UI: Developer Tools → YAML → Reload Automations.

Mobile notify target: set via `HA_NOTIFY_TARGET` in `.env` (default: `notify.mobile_app_sm_a536b`, admin phone Samsung SM-A536B).

## Next Session

**Tailscale** — remote access so push notifications and door open work outside the building network.

```bash
# Install on server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Then install Tailscale on phone and configure HA external URL to Tailscale IP
```

After Tailscale: wait for hardware delivery, then physical installation.

## Hardware (pending purchase/install)

- 2× Grandstream GDS3710 entrance panels (~150 EUR each)
- 4× Hikvision PoE cameras (2 per entrance)
- Intel N100 mini PC (server)
- PoE switch (16-port)
- 4G/LTE router (no wired internet in building)
- UPS + 6U wall cabinet (basement)
- Google Coral USB accelerator (swap `cpu1` detector in `frigate/config.yaml` for AI detection)
