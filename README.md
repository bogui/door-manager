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

Copy and fill in both secrets files:

```bash
cp .env.example .env
# edit .env — fill in PANEL_PASSWORD, CAM1_PASSWORD, CAM2_PASSWORD, TEST_PASSWORD, AMI_PASSWORD

cp homeassistant/secrets.yaml.example homeassistant/secrets.yaml
# edit homeassistant/secrets.yaml — put the full door-open URL with your PANEL_PASSWORD
```

`.env` is loaded by go2rtc (native `${VAR}` support) and Asterisk (via `entrypoint.sh`).  
`homeassistant/secrets.yaml` is loaded by Home Assistant natively via `!secret`.

### 2. Asterisk — envsubst requirement

The Asterisk entrypoint (`asterisk/entrypoint.sh`) uses `envsubst` to inject credentials into `pjsip.conf` and `manager.conf` before startup. If the image doesn't have it:

```bash
docker exec asterisk apt-get install -y gettext-base
```

Or add it to the entrypoint before the `envsubst` calls:
```sh
apt-get install -y gettext-base -qq
```

### 3. Start

```bash
docker compose up -d
```

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
