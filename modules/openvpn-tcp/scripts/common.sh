#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR=/etc/openvpn/halo-tcp
SERVER_CONFIG=/etc/openvpn/server/halo-tcp.conf
SERVICE=openvpn-server@halo-tcp
EASYRSA_BIN=/usr/share/easy-rsa/easyrsa
OPENVPN_BIN=/usr/sbin/openvpn

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "请使用 sudo 运行"
}

valid_client_name() {
  [[ $1 =~ ^[a-zA-Z0-9_-]{1,32}$ ]]
}

valid_subnet_prefix() {
  [[ $1 =~ ^10\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})$ ]] || return 1
  (( BASH_REMATCH[1] <= 255 && BASH_REMATCH[2] <= 255 ))
}

validate_config() {
  [[ ${SERVER_ENDPOINT:-} =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] ||
    die "SERVER_ENDPOINT 必须是公网 IP 或域名"
  [[ $SERVER_ENDPOINT != 203.0.113.10 ]] ||
    die "请把示例 SERVER_ENDPOINT 改为服务器真实地址"
  [[ ${OVPN_PORT:-} =~ ^[1-9][0-9]{0,4}$ ]] &&
    (( OVPN_PORT <= 65535 )) || die "OVPN_PORT 必须为 1-65535"
  valid_subnet_prefix "${OVPN_SUBNET_PREFIX:-}" ||
    die "OVPN_SUBNET_PREFIX 必须类似 10.66.67"
  [[ $OVPN_SUBNET_PREFIX != 10.66.66 ]] ||
    die "测试网段不能与现有 WireGuard 10.66.66.0/24 重叠"
  valid_client_name "${FIRST_CLIENT_NAME:-}" ||
    die "FIRST_CLIENT_NAME 只能包含字母、数字、下划线和连字符"
  [[ $FIRST_CLIENT_NAME != halo-tcp ]] ||
    die "客户端名不能与服务端证书名相同"
}

load_config() {
  local config_file=${1:-./deploy.env}
  [[ -f $config_file ]] || die "找不到 $config_file；请先复制 deploy.env.example"
  # shellcheck disable=SC1090
  source "$config_file"
  : "${SERVER_ENDPOINT:?请设置 SERVER_ENDPOINT}"
  OVPN_PORT=${OVPN_PORT:-1194}
  OVPN_SUBNET_PREFIX=${OVPN_SUBNET_PREFIX:-10.66.67}
  FIRST_CLIENT_NAME=${FIRST_CLIENT_NAME:-wsl-test}
  validate_config
}

load_metadata() {
  [[ -f $STATE_DIR/deploy.env ]] || die "找不到部署元数据，请先运行 install.sh"
  # 该文件由 root 在首次安装时生成，权限为 600。
  # shellcheck disable=SC1091
  source "$STATE_DIR/deploy.env"
  validate_config
}

easyrsa() {
  EASYRSA_PKI="$STATE_DIR/pki" \
    EASYRSA_BATCH=1 \
    EASYRSA_ALGO=ec \
    EASYRSA_CURVE=prime256v1 \
    "$EASYRSA_BIN" "$@"
}

render_server_config() {
  cat <<EOF
port $OVPN_PORT
proto tcp-server
dev tun-htcp
dev-type tun
topology subnet
server ${OVPN_SUBNET_PREFIX}.0 255.255.255.0
client-to-client
ca $STATE_DIR/pki/ca.crt
cert $STATE_DIR/pki/issued/halo-tcp.crt
key $STATE_DIR/pki/private/halo-tcp.key
dh none
ecdh-curve prime256v1
tls-crypt $STATE_DIR/tls-crypt.key
tls-version-min 1.2
data-ciphers AES-256-GCM
verify-client-cert require
allow-compression no
keepalive 10 60
persist-key
persist-tun
verb 3
EOF
}

render_client_config() {
  local client_name=$1 ca_file=$2 cert_file=$3 key_file=$4 tls_file=$5
  valid_client_name "$client_name" || die "客户端名称无效"
  cat <<EOF
client
dev tun
proto tcp-client
remote $SERVER_ENDPOINT $OVPN_PORT
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name halo-tcp name
tls-version-min 1.2
data-ciphers AES-256-GCM
allow-compression no
auth-nocache
verb 3
<ca>
EOF
  cat -- "$ca_file"
  printf '</ca>\n<cert>\n'
  cat -- "$cert_file"
  printf '</cert>\n<key>\n'
  cat -- "$key_file"
  printf '</key>\n<tls-crypt>\n'
  cat -- "$tls_file"
  printf '</tls-crypt>\n'
}
