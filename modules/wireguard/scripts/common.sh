#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "请使用 sudo 运行此脚本"
}

valid_interface() {
  [[ $1 =~ ^[a-zA-Z0-9_.-]{1,15}$ ]]
}

valid_client_name() {
  [[ $1 =~ ^[a-zA-Z0-9_-]{1,32}$ ]]
}

load_metadata() {
  local metadata=${WG_METADATA:-/etc/wireguard/deploy.env}
  [[ -f $metadata ]] || die "找不到 $metadata，请先运行 install.sh"
  # 该文件仅由 root 管理，并在写入前验证字段。
  # shellcheck disable=SC1090
  source "$metadata"
  valid_interface "$WG_INTERFACE" || die "元数据中的接口名无效"
  [[ $WG_SUBNET_PREFIX =~ ^10\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || die "元数据中的 VPN 网段无效"
  (( BASH_REMATCH[1] <= 255 && BASH_REMATCH[2] <= 255 )) || die "元数据中的 VPN 网段无效"
}

next_client_host() {
  local used host
  used=$(grep -hE '^Address = ' "$CLIENT_DIR"/*.conf 2>/dev/null | sed -E 's|/.*$||; s|.*\.||' || true)
  for host in $(seq 2 254); do
    [[ $host -eq $SERVER_VPN_HOST ]] && continue
    if ! grep -qx "$host" <<<"$used"; then
      printf '%s\n' "$host"
      return 0
    fi
  done
  die "VPN 网段中没有可用的客户端地址"
}

reload_interface() {
  if ip link show "$WG_INTERFACE" &>/dev/null; then
    wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
  fi
}
