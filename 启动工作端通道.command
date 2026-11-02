#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "此入口仅用于手动启动旧备用转发；日常无需运行，直接打开 Orca。"
exec "$SCRIPT_DIR/work-tunnel" backup-start
