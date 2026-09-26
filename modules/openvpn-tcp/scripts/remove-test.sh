#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
[[ ${1:-} == --confirm-remove-test-vpn ]] ||
  die "用法: sudo ./scripts/remove-test.sh --confirm-remove-test-vpn"
[[ $STATE_DIR == /etc/openvpn/halo-tcp &&
   $SERVER_CONFIG == /etc/openvpn/server/halo-tcp.conf ]] ||
  die "目标路径异常，拒绝清理"
[[ -f $STATE_DIR/.managed-by-halo-server ]] ||
  die "缺少本模块标记，拒绝删除"
grep -Fxq 'halo_server/modules/openvpn-tcp test instance' \
  "$STATE_DIR/.managed-by-halo-server" || die "实例标记不匹配，拒绝删除"

systemctl disable --now "$SERVICE" || die "无法停止测试服务，已保留配置"
rm -f -- "$SERVER_CONFIG"
rm -r -- "$STATE_DIR"
printf '测试实例配置和生成的证书已删除；openvpn/easy-rsa 软件包保留。\n'
printf '请在云安全组中删除测试用 TCP 入站规则。\n'
