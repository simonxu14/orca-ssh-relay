#!/bin/bash
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/config.sh"
if [ "${ORCA_RELAY_ROLE:-}" != home ]; then
  echo "仅在家里 Mac 使用：先在本机配置中设置 ORCA_RELAY_ROLE=home。" >&2
  exit 1
fi
HOST="${ORCA_RELAY_HOST:-}"
RELAY_USER="${ORCA_RELAY_HOME_USER:-orca-home-relay}"
SSH_PORT="${ORCA_RELAY_SSH_PORT:-22}"
RELAY_PORT="${ORCA_RELAY_REMOTE_PORT:-16768}"
ORCA_PORT="${ORCA_RELAY_ORCA_PORT:-6768}"
KNOWN="${ORCA_RELAY_KNOWN_HOSTS_FILE:-$ORCA_RELAY_ROOT/known_hosts.local}"
if [[ ! "$HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || [[ ! "$RELAY_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "请配置有效的 ORCA_RELAY_HOST 和 ORCA_RELAY_HOME_USER。" >&2
  exit 1
fi
require_port "$SSH_PORT"
require_port "$RELAY_PORT"
require_port "$ORCA_PORT"
if [ ! -s "$KNOWN" ]; then
  echo "请先从可信渠道核对中转服务器主机公钥，并保存到：$KNOWN" >&2
  exit 1
fi
STATE_DIR="$ORCA_RELAY_STATE_DIR"
KEY_DIR="$HOME/.ssh/orca-relay"
KEY="$KEY_DIR/home_ed25519"
CONFIG="$STATE_DIR/ssh_config_home"
PLIST="$STATE_DIR/dev.orca.home-ssh-relay.plist"
INSTALLED_PLIST="$HOME/Library/LaunchAgents/dev.orca.home-ssh-relay.plist"
if [ -e "$CONFIG" ] || [ -e "$PLIST" ] || [ -e "$INSTALLED_PLIST" ]; then
  echo "检测到家里端已有配置；为避免覆盖，请先查看现有配置。" >&2
  exit 1
fi
mkdir -p "$STATE_DIR" "$KEY_DIR"
chmod 700 "$STATE_DIR" "$KEY_DIR"
if [ ! -f "$KEY" ]; then
  /usr/bin/ssh-keygen -q -t ed25519 -N '' -C orca-home-relay -f "$KEY"
fi
chmod 600 "$KEY"
/usr/bin/ssh-keygen -y -f "$KEY" > "$KEY.pub"
cp "$KNOWN" "$STATE_DIR/known_hosts"
chmod 600 "$STATE_DIR/known_hosts"
cat > "$CONFIG" <<EOF
Host orca-cloud-home
    HostName $HOST
    User $RELAY_USER
    Port $SSH_PORT
    IdentityFile "$KEY"
    IdentitiesOnly yes
    BatchMode yes
    StrictHostKeyChecking yes
    UserKnownHostsFile "$STATE_DIR/known_hosts"
    GlobalKnownHostsFile /dev/null
    HostKeyAlgorithms ssh-ed25519
    UpdateHostKeys no
    ForwardAgent no
    ForwardX11 no
    GSSAPIAuthentication no
    RequestTTY no
    ControlMaster no
    ControlPath none
    ExitOnForwardFailure yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 10
    PermitRemoteOpen 127.0.0.1:$ORCA_PORT
    RemoteForward 127.0.0.1:$RELAY_PORT 127.0.0.1:$ORCA_PORT
EOF
chmod 600 "$CONFIG"
xml_escape() {
  /usr/bin/sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}
CONFIG_XML="$(printf '%s' "$CONFIG" | xml_escape)"
STATE_XML="$(printf '%s' "$STATE_DIR" | xml_escape)"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>dev.orca.home-ssh-relay</string>
<key>ProgramArguments</key><array>
<string>/usr/bin/ssh</string><string>-N</string><string>-T</string>
<string>-F</string><string>$CONFIG_XML</string><string>orca-cloud-home</string>
</array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>30</integer>
<key>StandardOutPath</key><string>$STATE_XML/home.stdout.log</string>
<key>StandardErrorPath</key><string>$STATE_XML/home.stderr.log</string>
</dict></plist>
EOF
chmod 600 "$PLIST"
/usr/bin/plutil -lint "$PLIST"
/usr/bin/ssh -F "$CONFIG" -G orca-cloud-home >/dev/null
echo "家里端已准备，尚未启动或安装自动启动项。请将下面的公钥登记到中转服务器："
cat "$KEY.pub"
echo "公钥登记完成后，运行 02-启动家里端.command。私钥留在本机。"
