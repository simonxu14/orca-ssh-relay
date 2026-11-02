#!/bin/bash
# Integration checks against real OpenSSH config parsing; never connects to a relay.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/orca-relay-test.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
TEST_HOME="$TEMP/home with spaces"
mkdir -p "$TEST_HOME"
ssh-keygen -q -t ed25519 -N '' -C orca-relay-offline-test -f "$TEMP/hostkey"
printf '[relay.example.test]:2222 %s\n' "$(cat "$TEMP/hostkey.pub")" > "$TEMP/known_hosts"
cat > "$TEMP/config.env" <<EOF
ORCA_RELAY_ROLE=home
ORCA_RELAY_HOST=relay.example.test
ORCA_RELAY_SSH_PORT=2222
ORCA_RELAY_REMOTE_PORT=26768
ORCA_RELAY_ORCA_PORT=7678
ORCA_RELAY_KNOWN_HOSTS_FILE='$TEMP/known_hosts'
EOF

if ! HOME="$TEST_HOME" ORCA_RELAY_CONFIG="$TEMP/config.env" \
  bash "$ROOT/home-install/01-准备家里端.command" > "$TEMP/prepare.out" 2>&1; then
  cat "$TEMP/prepare.out" >&2
  echo 'FAIL: home preparation must honor the supplied isolated configuration' >&2
  exit 1
fi
STATE="$TEST_HOME/Library/Application Support/Orca SSH Relay"
CONFIG="$STATE/ssh_config_home"
ssh -F "$CONFIG" -G orca-cloud-home > "$TEMP/effective.conf"
grep -Fxq 'hostname relay.example.test' "$TEMP/effective.conf"
grep -Fxq 'port 2222' "$TEMP/effective.conf"
grep -Fxq 'remoteforward [127.0.0.1]:26768 [127.0.0.1]:7678' "$TEMP/effective.conf"
grep -Fxq 'stricthostkeychecking true' "$TEMP/effective.conf"
grep -Fxq 'forwardagent no' "$TEMP/effective.conf"
test -f "$TEST_HOME/.ssh/orca-relay/home_ed25519"
test ! -e "$TEST_HOME/Library/LaunchAgents/dev.orca.home-ssh-relay.plist"
plutil -lint "$STATE/dev.orca.home-ssh-relay.plist" > /dev/null
echo 'PASS: custom configuration, quoted paths, loopback forwarding and staged-only setup'

BEFORE="$(shasum -a 256 "$CONFIG")"
if HOME="$TEST_HOME" ORCA_RELAY_CONFIG="$TEMP/config.env" \
  bash "$ROOT/home-install/01-准备家里端.command" > "$TEMP/repeat.out" 2>&1; then
  echo 'FAIL: repeated preparation must refuse to overwrite an existing setup' >&2
  exit 1
fi
test "$BEFORE" = "$(shasum -a 256 "$CONFIG")"
echo 'PASS: existing home configuration is preserved'

mkdir -p "$TEMP/missing-host-home"
printf "ORCA_RELAY_KNOWN_HOSTS_FILE='%s'\n" "$TEMP/does-not-exist" >> "$TEMP/config.env"
if HOME="$TEMP/missing-host-home" ORCA_RELAY_CONFIG="$TEMP/config.env" \
  bash "$ROOT/home-install/01-准备家里端.command" > "$TEMP/missing.out" 2>&1; then
  echo 'FAIL: missing pinned host keys must reject preparation' >&2
  exit 1
fi
test ! -d "$TEMP/missing-host-home/.ssh"
echo 'PASS: missing pinned host keys fail before creating keys or state'

mkdir -p "$TEMP/invalid-port-home"
printf "ORCA_RELAY_KNOWN_HOSTS_FILE='%s'\nORCA_RELAY_REMOTE_PORT=999999\n" \
  "$TEMP/known_hosts" >> "$TEMP/config.env"
if HOME="$TEMP/invalid-port-home" ORCA_RELAY_CONFIG="$TEMP/config.env" \
  bash "$ROOT/home-install/01-准备家里端.command" > "$TEMP/invalid.out" 2>&1; then
  echo 'FAIL: an invalid relay port must reject preparation' >&2
  exit 1
fi
test ! -d "$TEMP/invalid-port-home/.ssh"
echo 'PASS: invalid ports fail before creating keys or state'
