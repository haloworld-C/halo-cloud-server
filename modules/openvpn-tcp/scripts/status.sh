#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
load_metadata

printf '服务：%s\n' "$SERVICE"
systemctl is-active "$SERVICE" || true
printf '监听端口：TCP %s\n' "$OVPN_PORT"
ss -lnt "sport = :$OVPN_PORT"
printf '测试接口：\n'
ip -4 address show dev tun-htcp || true
printf '客户端配置：\n'
find "$STATE_DIR/clients" -maxdepth 1 -type f -name '*.ovpn' -printf '%f\n'
