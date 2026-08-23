#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
load_metadata

CLIENT_NAME=${1:-}
valid_client_name "$CLIENT_NAME" || die "用法: $0 <客户端名>（字母、数字、下划线或短横线）"
CLIENT_CONFIG=$CLIENT_DIR/${CLIENT_NAME}.conf
[[ ! -e $CLIENT_CONFIG ]] || die "客户端 $CLIENT_NAME 已存在"

CLIENT_HOST=$(next_client_host)
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(wg pubkey <<<"$CLIENT_PRIVATE_KEY")
SERVER_PUBLIC_KEY=$(<"$SERVER_PUBLIC_KEY_FILE")

umask 077
cat > "$CLIENT_CONFIG" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = ${WG_SUBNET_PREFIX}.${CLIENT_HOST}/32
DNS = $CLIENT_DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = ${SERVER_ENDPOINT}:${WG_PORT}
AllowedIPs = $CLIENT_ALLOWED_IPS
PersistentKeepalive = 25
EOF
chmod 600 "$CLIENT_CONFIG"

cat >> "/etc/wireguard/${WG_INTERFACE}.conf" <<EOF

# client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = ${WG_SUBNET_PREFIX}.${CLIENT_HOST}/32
EOF

reload_interface
printf '已创建客户端: %s\n配置文件: %s\nVPN 地址: %s.%s\n' \
  "$CLIENT_NAME" "$CLIENT_CONFIG" "$WG_SUBNET_PREFIX" "$CLIENT_HOST"
if command -v qrencode >/dev/null; then
  printf '二维码（仅在可信终端显示）：sudo qrencode -t ansiutf8 < %s\n' "$CLIENT_CONFIG"
fi
