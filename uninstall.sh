#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_BIN="$ROOT_DIR/bin/gh"
LINK_DIR="${GH_SANDBOX_LINK_DIR:-$HOME/.local/bin}"
LINK_PATH="$LINK_DIR/gh"
SYSTEM_LINK_PATH="${GH_SANDBOX_SYSTEM_LINK_PATH:-/usr/local/bin/gh}"
SYSTEM_BACKUP_PATH="${SYSTEM_LINK_PATH}.original-before-gh-sandbox-proxy"
ZSHENV_PATH="${GH_SANDBOX_ZSHENV_PATH:-$HOME/.zshenv}"
CONTAINER_NAME="${GH_SANDBOX_CONTAINER_NAME:-gh-sandbox-proxy-${USER:-user}}"
AUTH_VOLUME_NAME="${CONTAINER_NAME}-auth"

if [[ -L "$LINK_PATH" && "$(readlink "$LINK_PATH")" == "$WRAPPER_BIN" ]]; then
  rm -f "$LINK_PATH"
  echo "removed user symlink: $LINK_PATH"
fi

if [[ -L "$SYSTEM_LINK_PATH" && "$(readlink "$SYSTEM_LINK_PATH")" == "$WRAPPER_BIN" ]]; then
  rm -f "$SYSTEM_LINK_PATH"
  echo "removed system symlink: $SYSTEM_LINK_PATH"
  if [[ -e "$SYSTEM_BACKUP_PATH" || -L "$SYSTEM_BACKUP_PATH" ]]; then
    mv "$SYSTEM_BACKUP_PATH" "$SYSTEM_LINK_PATH"
    echo "restored original gh: $SYSTEM_LINK_PATH"
  fi
fi

if [[ -f "$ZSHENV_PATH" ]]; then
  ZSHENV_TARGET="$ZSHENV_PATH" python3 - <<'PY'
import os
from pathlib import Path

target = Path(os.environ["ZSHENV_TARGET"])
begin = "# >>> gh-sandbox-proxy PATH >>>"
end = "# <<< gh-sandbox-proxy PATH <<<"
text = target.read_text()
if begin in text and end in text:
    before, rest = text.split(begin, 1)
    _, after = rest.split(end, 1)
    target.write_text((before.rstrip() + "\n" + after.lstrip()).rstrip() + "\n")
    print(f"removed zshenv PATH shim: {target}")
PY
fi

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker volume rm -f "$AUTH_VOLUME_NAME" >/dev/null 2>&1 || true

echo "uninstall complete"
