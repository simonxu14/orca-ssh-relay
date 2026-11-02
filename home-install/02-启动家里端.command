#!/bin/bash
set -euo pipefail
LABEL=dev.orca.home-ssh-relay
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/config.sh"
if [ "${ORCA_RELAY_ROLE:-}" != home ]; then
  echo "仅在家里 Mac 使用：请配置 ORCA_RELAY_ROLE=home。" >&2
  exit 1
fi
STATE_DIR="$ORCA_RELAY_STATE_DIR"
STAGED_PLIST="$STATE_DIR/$LABEL.plist"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
if [ ! -f "$STAGED_PLIST" ]; then
  echo "请先运行 01-准备家里端.command 并完成公钥登记。" >&2
  exit 1
fi
ORCA_PORT="${ORCA_RELAY_ORCA_PORT:-6768}"
require_port "$ORCA_PORT"
if ! /usr/bin/curl --noproxy '*' --fail --silent --show-error --max-time 3 "http://127.0.0.1:$ORCA_PORT/" -o /dev/null; then
  echo "家里 Orca 服务尚不可达，请先打开 Orca 并启用 Share this host。" >&2
  exit 2
fi
mkdir -p "$HOME/Library/LaunchAgents"
cp "$STAGED_PLIST" "$PLIST"
chmod 600 "$PLIST"
if /bin/launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  /bin/launchctl kickstart -k "gui/$(id -u)/$LABEL"
else
  /bin/launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi
echo "已启动家里端后台连接，登录此 Mac 后也会自动启动；异常断线会重试。"
echo "这不代表 Orca 已完成配对。请在工作电脑启动通道后检查实际连通性。"
echo "诊断日志：$HOME/Library/Application Support/Orca SSH Relay/home.stderr.log"
