#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root

CONFIG_FILE=${1:-./deploy.env}
[[ -f $CONFIG_FILE ]] || die "找不到配置文件 $CONFIG_FILE；请先复制 deploy.env.example"
# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${SERVER_ENDPOINT:?请在配置文件中设置 SERVER_ENDPOINT}"
WG_INTERFACE=${WG_INTERFACE:-wg0}
WG_PORT=${WG_PORT:-51820}
WG_SUBNET_PREFIX=${WG_SUBNET_PREFIX:-10.66.66}
SERVER_VPN_HOST=${SERVER_VPN_HOST:-1}
FIRST_CLIENT_NAME=${FIRST_CLIENT_NAME:-client1}
CLIENT_DNS=${CLIENT_DNS:-1.1.1.1, 1.0.0.1}
CLIENT_ALLOWED_IPS=${CLIENT_ALLOWED_IPS:-0.0.0.0/0}
PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-}

valid_interface "$WG_INTERFACE" || die "WG_INTERFACE 无效"
valid_client_name "$FIRST_CLIENT_NAME" || die "FIRST_CLIENT_NAME 无效"
[[ $WG_PORT =~ ^[0-9]+$ ]] && (( WG_PORT >= 1 && WG_PORT <= 65535 )) || die "WG_PORT 必须为 1-65535"
[[ $SERVER_VPN_HOST =~ ^[0-9]+$ ]] && (( SERVER_VPN_HOST >= 1 && SERVER_VPN_HOST <= 254 )) || die "SERVER_VPN_HOST 必须为 1-254"
[[ $WG_SUBNET_PREFIX =~ ^10\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || die "WG_SUBNET_PREFIX 必须类似 10.66.66"
(( BASH_REMATCH[1] <= 255 && BASH_REMATCH[2] <= 255 )) || die "WG_SUBNET_PREFIX 无效"
[[ $SERVER_ENDPOINT =~ ^[a-zA-Z0-9.-]+$ ]] || die "SERVER_ENDPOINT 只能是 IP 或域名"

if [[ -z $PUBLIC_INTERFACE ]]; then
  PUBLIC_INTERFACE=$(ip -4 route show default | awk 'NR==1 {print $5}')
fi
valid_interface "$PUBLIC_INTERFACE" || die "无法探测公网出口网卡，请设置 PUBLIC_INTERFACE"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
else
  die "无法识别操作系统"
fi
case ${ID:-} in
  ubuntu|debian) ;;
  *) die "当前仅支持 Ubuntu/Debian，检测到: ${ID:-未知}" ;;
esac

WG_CONFIG=/etc/wireguard/${WG_INTERFACE}.conf
if [[ -e $WG_CONFIG ]]; then
  die "$WG_CONFIG 已存在；为避免覆盖现有 VPN，安装已停止"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard iptables procps qrencode

SYSCTL_BIN=$(command -v sysctl || true)
if [[ -z $SYSCTL_BIN && -x /usr/sbin/sysctl ]]; then
  SYSCTL_BIN=/usr/sbin/sysctl
fi
[[ -n $SYSCTL_BIN ]] || die "安装 procps 后仍找不到 sysctl"

if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  ufw allow "${WG_PORT}/udp" comment 'WireGuard'
fi

install -d -m 700 /etc/wireguard /etc/wireguard/clients
SERVER_PRIVATE_KEY_FILE=/etc/wireguard/server.key
SERVER_PUBLIC_KEY_FILE=/etc/wireguard/server.pub
if [[ ! -f $SERVER_PRIVATE_KEY_FILE ]]; then
  umask 077
  wg genkey | tee "$SERVER_PRIVATE_KEY_FILE" | wg pubkey > "$SERVER_PUBLIC_KEY_FILE"
fi
chmod 600 "$SERVER_PRIVATE_KEY_FILE" "$SERVER_PUBLIC_KEY_FILE"

SERVER_PRIVATE_KEY=$(<"$SERVER_PRIVATE_KEY_FILE")
install -m 600 /dev/null "$WG_CONFIG"
printf '%s\n' \
  '[Interface]' \
  "Address = ${WG_SUBNET_PREFIX}.${SERVER_VPN_HOST}/24" \
  "ListenPort = ${WG_PORT}" \
  "PrivateKey = ${SERVER_PRIVATE_KEY}" \
  "PostUp = iptables -I FORWARD -i %i -j ACCEPT; iptables -I FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -s ${WG_SUBNET_PREFIX}.0/24 -o ${PUBLIC_INTERFACE} -j MASQUERADE" \
  "PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s ${WG_SUBNET_PREFIX}.0/24 -o ${PUBLIC_INTERFACE} -j MASQUERADE" \
  > "$WG_CONFIG"

cat > /etc/sysctl.d/99-wireguard-routing.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
"$SYSCTL_BIN" --system >/dev/null
"$SYSCTL_BIN" -w net.ipv4.ip_forward=1 >/dev/null
[[ $("$SYSCTL_BIN" -n net.ipv4.ip_forward) == 1 ]] || die "无法启用 IPv4 转发"

METADATA=/etc/wireguard/deploy.env
install -m 600 /dev/null "$METADATA"
{
  printf 'WG_INTERFACE=%q\n' "$WG_INTERFACE"
  printf 'WG_PORT=%q\n' "$WG_PORT"
  printf 'WG_SUBNET_PREFIX=%q\n' "$WG_SUBNET_PREFIX"
  printf 'SERVER_VPN_HOST=%q\n' "$SERVER_VPN_HOST"
  printf 'SERVER_ENDPOINT=%q\n' "$SERVER_ENDPOINT"
  printf 'CLIENT_DNS=%q\n' "$CLIENT_DNS"
  printf 'CLIENT_ALLOWED_IPS=%q\n' "$CLIENT_ALLOWED_IPS"
  printf 'CLIENT_DIR=%q\n' /etc/wireguard/clients
  printf 'SERVER_PUBLIC_KEY_FILE=%q\n' "$SERVER_PUBLIC_KEY_FILE"
} > "$METADATA"

systemctl enable --now "wg-quick@${WG_INTERFACE}"
WG_METADATA=$METADATA "$SCRIPT_DIR/add-client.sh" "$FIRST_CLIENT_NAME"

printf '\n安装完成。\n服务端: %s:%s\n客户端配置: /etc/wireguard/clients/%s.conf\n' \
  "$SERVER_ENDPOINT" "$WG_PORT" "$FIRST_CLIENT_NAME"
printf '云安全组需放行 UDP %s。\n' "$WG_PORT"
