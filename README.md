# door-manager

Self-hosted IP intercom system for a residential building (23 apartments, 2 entrances). Replaces an analog домофон with video doorbells, RFID access, SIP calls to tenants' phones, and a mobile app with push notifications and one-tap door open.

Built on a Docker stack running on a single Intel N100 mini PC in the basement.

## Stack

| Service | Image | Role |
|---|---|---|
| go2rtc | alexxit/go2rtc | Camera stream proxy (RTSP → WebRTC) |
| Mosquitto | eclipse-mosquitto | MQTT broker |
| Frigate | blakeblackshear/frigate:stable | NVR, motion/person detection |
| Home Assistant | home-assistant/home-assistant:stable | Automation hub, mobile app, push notifications |
| Asterisk | andrius/asterisk:18 | SIP PBX — routes doorbell calls to apartments |

All containers run with `network_mode: host` — inter-service communication uses `127.0.0.1`.

## How it works

**Doorbell → phone:**
1. Visitor presses button on entrance panel (Grandstream GDS3710)
2. Panel initiates SIP call to Asterisk
3. Asterisk POSTs to a Home Assistant webhook before ringing
4. HA sends a push notification with a camera snapshot and an "Open Door" action button
5. Asterisk rings the apartment SIP extension

**Door open:**
Resident taps "Open Door" → HA calls the GDS3710 HTTP API → door relay triggers.

**Cameras:**
go2rtc pulls RTSP streams from all cameras and panels. Frigate connects to go2rtc — never directly to cameras. HA uses the Frigate integration (via HACS) for snapshots and motion events.

## Deployment

### 1. Credentials

```bash
cp .env.example .env
# edit .env — fill in all hosts, usernames, and passwords
```

All per-deployment values (IPs, usernames, passwords, HA notify target) live in `.env`. Docker Compose injects them into go2rtc, Asterisk, and Home Assistant automatically. See `.env.example` for the full list and comments.

### 2. Start

```bash
docker compose up -d
```

### 3. Home Assistant first-run

Open `http://<server-ip>:8123` in a browser. HA will walk you through creating an admin account on first launch.

### 4. Install HACS (Home Assistant Community Store)

HACS is required for the Frigate integration.

```bash
docker exec homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"
```

Then restart HA:

```bash
docker compose restart homeassistant
```

In the HA UI: **Settings → Devices & Services → Add Integration** → search **HACS** → follow the prompts (requires a GitHub account to authorize).

### 5. Connect Home Assistant to MQTT

Frigate uses MQTT to push entity states to HA. Without this, all Frigate sensors show as Unavailable.

**Settings → Devices & Services → Add Integration → MQTT**

- Broker: `127.0.0.1`
- Port: `1883`
- Username / Password: leave blank

### 6. Install the Frigate integration

In HACS: **HACS → Integrations → Explore & Download** → search **Frigate** → Download.

Restart HA again:

```bash
docker compose restart homeassistant
```

Then: **Settings → Devices & Services → Add Integration** → search **Frigate** → set the URL to `http://127.0.0.1:5000`.

Camera entities (`camera.south_panel`, `camera.south_cam1`, `camera.south_cam2`) appear automatically based on the stream names in `frigate/config.yaml`. No manual camera config needed in HA.

## Network

Building network: `192.168.1.x`

| Device | IP |
|---|---|
| Server | 192.168.1.10 |
| South entrance panel (GDS3710) | 192.168.1.20 |
| South cam 1 (Hikvision) | 192.168.1.31 |
| South cam 2 (Hikvision) | 192.168.1.32 |

## Hardware

- 2× Grandstream GDS3710 entrance panels
- 4× Hikvision PoE cameras (2 per entrance)
- Intel N100 mini PC
- 16-port PoE switch
- 4G/LTE router
- UPS + 6U wall cabinet (basement)
- Grandstream GXW4224 (24-port FXS gateway for analog handsets — Phase 3)
- Google Coral USB accelerator (optional — swap `cpu1` detector in `frigate/config.yaml`)

## Roadmap

- **Phase 1** — South entrance (greenfield) ✓ in dev/test
- **Phase 2** — North entrance (integrate with existing analog system)
- **Phase 3** — Per-apartment SIP extensions; analog handsets via GXW4224 FXS gateway
