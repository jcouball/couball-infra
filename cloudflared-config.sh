#!/bin/bash

# Validate required variables
if [[ -z "${account_id}" || -z "${tunnel_id}" || -z "${tunnel_name}" || -z "${tunnel_secret}" ]]; then
    echo "Error: Required environment variables are not set: account_id, tunnel_id, tunnel_name, tunnel_secret"
    exit 1
fi

# fail if any command fails
set -ex

apt update -y
apt upgrade -y
apt install -y curl

curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb

mkdir -p /etc/cloudflared
chmod 750 /etc/cloudflared

# /etc/cloudflared/cert.json

cat > /etc/cloudflared/cert.json << "EOF"
{
    "AccountTag"   : "${account_id}",
    "TunnelID"     : "${tunnel_id}",
    "TunnelName"   : "${tunnel_name}",
    "TunnelSecret" : "${tunnel_secret}"
}
EOF
chmod 600 /etc/cloudflared/cert.json

# /etc/cloudflared/config.yml

cat > /etc/cloudflared/config.yml << "EOF"
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/cert.json
logfile: /var/log/cloudflared.log
loglevel: info

ingress:
  - hostname: www.couball.dev
    service: http://192.168.2.102:8080
  - hostname: "*"
    service: "http_status:404"
EOF

if systemctl is-active --quiet cloudflared; then
  systemctl restart cloudflared
else
  cloudflared service install
fi

# Verify cloudflared service status
systemctl is-enabled cloudflared
systemctl is-active cloudflared
