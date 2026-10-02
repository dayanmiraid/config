# Northflank VLESS WebSocket

## Environment variables

- `UUID`: required VLESS UUID
- `WS_PATH`: secret WebSocket path, for example `/a8f3c91d`
- `CONFIG_KEY`: secret key for the configuration page
- `PORT`: optional; defaults to `8080`

## Northflank port

Create one public port:

- Internal port: `8080`
- Protocol: `HTTP`
- Public: enabled

Use the generated `*.code.run` domain.

## Health check

Path: `/health`

## Get the VLESS link

Open:

`https://YOUR-DOMAIN.code.run/config?key=YOUR_CONFIG_KEY`

Keep UUID and CONFIG_KEY private. This project supports TCP traffic through VLESS over WebSocket; it does not provide UDP/WireGuard.
