#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
load_metadata

CLIENT_NAME=${1:-}
valid_client_name "$CLIENT_NAME" || die "用法: $0 <客户端名>"
CLIENT_CONFIG=$CLIENT_DIR/${CLIENT_NAME}.conf
[[ -f $CLIENT_CONFIG ]] || die "客户端 $CLIENT_NAME 不存在"

WG_CONFIG=/etc/wireguard/${WG_INTERFACE}.conf
TEMP_CONFIG=$(mktemp "/etc/wireguard/.${WG_INTERFACE}.conf.XXXXXX")
trap 'rm -f -- "$TEMP_CONFIG"' EXIT
if ! awk -v marker="# client: $CLIENT_NAME" '
  $0 == marker { skipping = 1; found++; next }
  skipping && /^# client: / { skipping = 0 }
  !skipping { print }
  END { if (found != 1) exit 42 }
' "$WG_CONFIG" > "$TEMP_CONFIG"; then
  die "服务端配置中未找到唯一的客户端条目: $CLIENT_NAME"
fi
chmod 600 "$TEMP_CONFIG"
mv -- "$TEMP_CONFIG" "$WG_CONFIG"
trap - EXIT

rm -f -- "$CLIENT_CONFIG"
reload_interface
printf '已删除客户端 %s；其旧配置已立即失效。\n' "$CLIENT_NAME"
