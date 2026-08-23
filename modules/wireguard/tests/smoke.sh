#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../scripts/common.sh
source "$PROJECT_DIR/scripts/common.sh"

TEST_ROOT=$(mktemp -d)
cleanup() {
  rm -f -- "$TEST_ROOT"/*
  rmdir -- "$TEST_ROOT"
}
trap cleanup EXIT

CLIENT_DIR=$TEST_ROOT
WG_SUBNET_PREFIX=10.66.66
SERVER_VPN_HOST=1

[[ $(next_client_host) == 2 ]]
printf '[Interface]\nAddress = 10.66.66.2/32\n' > "$CLIENT_DIR/a.conf"
printf '[Interface]\nAddress = 10.66.66.3/32\n' > "$CLIENT_DIR/b.conf"
[[ $(next_client_host) == 4 ]]

WG_CONFIG=$TEST_ROOT/wg0.conf
cat > "$WG_CONFIG" <<'EOF'
[Interface]
Address = 10.66.66.1/24

# client: a
[Peer]
PublicKey = aaa
AllowedIPs = 10.66.66.2/32

# client: b
[Peer]
PublicKey = bbb
AllowedIPs = 10.66.66.3/32
EOF

awk -v marker='# client: a' '
  $0 == marker { skipping = 1; found++; next }
  skipping && /^# client: / { skipping = 0 }
  !skipping { print }
  END { if (found != 1) exit 42 }
' "$WG_CONFIG" > "$TEST_ROOT/result.conf"

! grep -q 'PublicKey = aaa' "$TEST_ROOT/result.conf"
grep -q 'PublicKey = bbb' "$TEST_ROOT/result.conf"

printf 'smoke tests passed\n'
