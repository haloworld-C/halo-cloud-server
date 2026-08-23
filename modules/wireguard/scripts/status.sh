#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
load_metadata

systemctl --no-pager --full status "wg-quick@${WG_INTERFACE}" || true
printf '\nWireGuard 状态:\n'
wg show "$WG_INTERFACE"
printf '\nIPv4 转发: '
sysctl -n net.ipv4.ip_forward
printf '客户端配置:\n'
find "$CLIENT_DIR" -maxdepth 1 -type f -name '*.conf' -printf '  %f\n' | sort
