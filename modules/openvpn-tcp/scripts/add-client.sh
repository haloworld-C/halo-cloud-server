#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
load_metadata

client_name=${1:-}
valid_client_name "$client_name" || die "用法: sudo ./scripts/add-client.sh <客户端名称>"
[[ $client_name != halo-tcp ]] || die "客户端名不能与服务端证书名相同"
client_file="$STATE_DIR/clients/$client_name.ovpn"
[[ ! -e $client_file && ! -e $STATE_DIR/pki/issued/$client_name.crt ]] ||
  die "客户端 $client_name 已存在；不会覆盖密钥"

umask 077
easyrsa build-client-full "$client_name" nopass
tmp_file=$(mktemp "$STATE_DIR/clients/.$client_name.XXXXXX")
trap 'rm -f -- "$tmp_file"' EXIT
render_client_config "$client_name" \
  "$STATE_DIR/pki/ca.crt" \
  "$STATE_DIR/pki/issued/$client_name.crt" \
  "$STATE_DIR/pki/private/$client_name.key" \
  "$STATE_DIR/tls-crypt.key" > "$tmp_file"
chmod 600 "$tmp_file"
mv --no-clobber -- "$tmp_file" "$client_file"
[[ -f $client_file ]] || die "无法保存客户端配置"
[[ ! -e $tmp_file ]] || die "客户端配置目标被并发创建；不会覆盖"
trap - EXIT
printf '客户端配置：%s\n' "$client_file"
printf '配置包含未加密的客户端私钥，请仅通过可信通道传输。\n'
