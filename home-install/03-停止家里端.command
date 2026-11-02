#!/bin/bash
set -euo pipefail
LABEL=dev.orca.home-ssh-relay
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/config.sh"
if [ "${ORCA_RELAY_ROLE:-}" != home ]; then
  echo "仅在家里 Mac 使用：请配置 ORCA_RELAY_ROLE=home。" >&2
  exit 1
fi
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STAGED_PLIST="$ORCA_RELAY_STATE_DIR/$LABEL.plist"
if /bin/launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  /bin/launchctl bootout "gui/$(id -u)/$LABEL"
  echo "家里端 SSH 通道已停止；Orca 本身不受此命令影响。"
else
  echo "家里端 SSH 通道未运行。"
fi
if [ -f "$PLIST" ]; then
  if [ ! -f "$STAGED_PLIST" ]; then
    mv "$PLIST" "$STAGED_PLIST"
  else
    cmp -s "$PLIST" "$STAGED_PLIST" || { echo "启动项与备份不一致，保留文件供检查。" >&2; exit 1; }
    rm "$PLIST"
  fi
  echo "已移除登录自动启动项。再次启用请运行 02-启动家里端.command。"
fi
