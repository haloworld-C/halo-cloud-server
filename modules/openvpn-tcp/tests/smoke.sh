#!/usr/bin/env bash
set -Eeuo pipefail

MODULE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../scripts/common.sh
source "$MODULE_DIR/scripts/common.sh"

SERVER_ENDPOINT=198.51.100.10
OVPN_PORT=1194
OVPN_SUBNET_PREFIX=10.66.67
FIRST_CLIENT_NAME=wsl-test
validate_config
if (OVPN_SUBNET_PREFIX=10.66.66; validate_config) >/dev/null 2>&1; then
  die "未拒绝与 WireGuard 重叠的网段"
fi
if (OVPN_PORT=65536; validate_config) >/dev/null 2>&1; then
  die "未拒绝非法端口"
fi
if (FIRST_CLIENT_NAME='../bad'; validate_config) >/dev/null 2>&1; then
  die "未拒绝非法客户端名称"
fi

server_config=$(render_server_config)
grep -qx 'proto tcp-server' <<< "$server_config"
grep -qx 'server 10.66.67.0 255.255.255.0' <<< "$server_config"
grep -qx 'client-to-client' <<< "$server_config"
! grep -q 'redirect-gateway' <<< "$server_config"

test_dir=$(mktemp -d)
cleanup() {
  rm -f -- "$test_dir"/{ca,cert,key,tls}
  rmdir -- "$test_dir"
}
trap cleanup EXIT
for item in ca cert key tls; do
  printf '%s\n' "$item" > "$test_dir/$item"
done
client_config=$(render_client_config wsl-test \
  "$test_dir/ca" "$test_dir/cert" "$test_dir/key" "$test_dir/tls")
grep -qx 'proto tcp-client' <<< "$client_config"
grep -qx 'remote 198.51.100.10 1194' <<< "$client_config"
grep -qx 'verify-x509-name halo-tcp name' <<< "$client_config"
grep -qx '<tls-crypt>' <<< "$client_config"
! grep -q 'redirect-gateway' <<< "$client_config"

printf 'openvpn-tcp smoke tests passed\n'
