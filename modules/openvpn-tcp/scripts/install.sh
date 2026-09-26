#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
load_config "${1:-./deploy.env}"

[[ ! -e $STATE_DIR && ! -e $SERVER_CONFIG ]] ||
  die "测试实例已存在；不会覆盖现有配置"
[[ ! -e /sys/class/net/tun-htcp ]] ||
  die "tun-htcp 接口已存在；请先确认其来源"
if ss -lntH "sport = :$OVPN_PORT" | grep -q .; then
  die "TCP $OVPN_PORT 已被占用"
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
else
  die "无法识别操作系统"
fi
case ${ID:-} in
  debian|ubuntu) ;;
  *) die "当前仅支持 Debian/Ubuntu" ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y openvpn easy-rsa
[[ -x $EASYRSA_BIN ]] || die "安装后找不到 $EASYRSA_BIN"
[[ -x $OPENVPN_BIN ]] || die "安装后找不到 $OPENVPN_BIN"

umask 077
install -d -m 700 "$STATE_DIR" "$STATE_DIR/clients"
[[ -d /etc/openvpn/server ]] || install -d -m 755 /etc/openvpn/server
printf '%s\n' 'halo_server/modules/openvpn-tcp test instance' > "$STATE_DIR/.managed-by-halo-server"

easyrsa init-pki
EASYRSA_REQ_CN=halo-tcp-ca easyrsa build-ca nopass
easyrsa build-server-full halo-tcp nopass
"$OPENVPN_BIN" --genkey tls-crypt "$STATE_DIR/tls-crypt.key"

install -m 600 /dev/null "$SERVER_CONFIG"
render_server_config > "$SERVER_CONFIG"
install -m 600 /dev/null "$STATE_DIR/deploy.env"
{
  printf 'SERVER_ENDPOINT=%q\n' "$SERVER_ENDPOINT"
  printf 'OVPN_PORT=%q\n' "$OVPN_PORT"
  printf 'OVPN_SUBNET_PREFIX=%q\n' "$OVPN_SUBNET_PREFIX"
  printf 'FIRST_CLIENT_NAME=%q\n' "$FIRST_CLIENT_NAME"
} > "$STATE_DIR/deploy.env"

systemctl enable --now "$SERVICE"
"$SCRIPT_DIR/add-client.sh" "$FIRST_CLIENT_NAME"

printf 'OpenVPN TCP 测试实例已启动：TCP %s，网段 %s.0/24\n' \
  "$OVPN_PORT" "$OVPN_SUBNET_PREFIX"
printf '客户端配置：%s/clients/%s.ovpn\n' "$STATE_DIR" "$FIRST_CLIENT_NAME"
printf '请在云安全组放行 TCP %s；本实例不改变默认路由或 WireGuard。\n' "$OVPN_PORT"
