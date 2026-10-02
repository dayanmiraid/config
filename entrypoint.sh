#!/bin/sh
set -eu

: "${UUID:?Set UUID in environment variables}"

WS_PATH="${WS_PATH:-/vless}"
CONFIG_KEY="${CONFIG_KEY:-change-this-key}"
PORT="${PORT:-8080}"

case "$WS_PATH" in
  /*) ;;
  *) WS_PATH="/$WS_PATH" ;;
esac

if ! printf '%s' "$UUID" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'; then
  echo "Invalid UUID" >&2
  exit 1
fi

if ! printf '%s' "$WS_PATH" | grep -Eq '^/[A-Za-z0-9._~/-]+$'; then
  echo "Invalid WS_PATH" >&2
  exit 1
fi

if ! printf '%s' "$CONFIG_KEY" | grep -Eq '^[A-Za-z0-9._~-]+$'; then
  echo "Invalid CONFIG_KEY" >&2
  exit 1
fi

PATH_ENCODED=$(printf '%s' "$WS_PATH" | sed 's|/|%2F|g')

mkdir -p /etc/xray /run/nginx

cat > /etc/xray/config.json <<XRAY
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${UUID}" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
XRAY

cat > /etc/nginx/nginx.conf <<NGINX
worker_processes auto;
pid /run/nginx.pid;
error_log /dev/stderr warn;

events {
  worker_connections 1024;
}

http {
  access_log /dev/stdout;

  server {
    listen ${PORT};
    server_name _;

    location = / {
      default_type text/plain;
      add_header Cache-Control "no-store";
      return 200 "Northflank VLESS is running\n";
    }

    location = /health {
      default_type text/plain;
      return 200 "OK\n";
    }

    location = /config {
      if (\$arg_key != "${CONFIG_KEY}") { return 404; }
      default_type text/plain;
      add_header Cache-Control "no-store";
      return 200 "vless://${UUID}@\$host:443?encryption=none&security=tls&sni=\$host&fp=chrome&type=ws&host=\$host&path=${PATH_ENCODED}#Northflank-VLESS\n";
    }

    location = ${WS_PATH} {
      proxy_pass http://127.0.0.1:10000;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host \$host;
      proxy_read_timeout 86400s;
      proxy_send_timeout 86400s;
      proxy_buffering off;
    }

    location / {
      return 404;
    }
  }
}
NGINX

/usr/local/bin/xray run -config /etc/xray/config.json &
XRAY_PID=$!
trap 'kill "$XRAY_PID" 2>/dev/null || true' EXIT INT TERM
nginx -g 'daemon off;'
