#!/bin/bash
ORCA_RELAY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_ENV="${ORCA_RELAY_CONFIG:-$ORCA_RELAY_ROOT/config.local.env}"
if [ -n "${ORCA_RELAY_CONFIG:-}" ] && [ ! -f "$CONFIG_ENV" ]; then
  echo "配置文件不存在：$CONFIG_ENV" >&2
  exit 1
fi
if [ -f "$CONFIG_ENV" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$CONFIG_ENV"
  set +a
fi
ORCA_RELAY_STATE_DIR="${ORCA_RELAY_STATE_DIR:-$HOME/Library/Application Support/Orca SSH Relay}"
ORCA_APP_PATH="${ORCA_APP_PATH:-/Applications/Orca.app}"
export ORCA_APP_PATH
require_port() {
  local value="$1"
  if [[ ! "$value" =~ ^[0-9]{1,5}$ ]] || ! (( 10#$value >= 1 && 10#$value <= 65535 )); then
    echo "端口必须在 1–65535 之间。" >&2
    exit 1
  fi
}
