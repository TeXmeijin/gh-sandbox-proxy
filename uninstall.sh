#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_BIN="$ROOT_DIR/bin/gh"
LINK_DIR="${GH_GHTKN_GUARD_LINK_DIR:-$HOME/.local/bin}"
LINK_PATH="$LINK_DIR/gh"
SYSTEM_LINK_PATH="${GH_GHTKN_GUARD_SYSTEM_LINK_PATH:-/usr/local/bin/gh}"
SYSTEM_BACKUP_PATH="${SYSTEM_LINK_PATH}.original-before-gh-ghtkn-guard"
ZSHENV_PATH="${GH_GHTKN_GUARD_ZSHENV_PATH:-$HOME/.zshenv}"
ZPROFILE_PATH="$HOME/.zprofile"
ZSHRC_PATH="$HOME/.zshrc"

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

remove_zsh_path_block() {
  local target_file="$1"
  [[ -f "$target_file" ]] || return 0
  ZSH_TARGET="$target_file" python3 - <<'PY'
import os
from pathlib import Path

target = Path(os.environ["ZSH_TARGET"])
begin = "# >>> gh-ghtkn-guard PATH >>>"
end = "# <<< gh-ghtkn-guard PATH <<<"
text = target.read_text()
if begin in text and end in text:
    before, rest = text.split(begin, 1)
    _, after = rest.split(end, 1)
    target.write_text((before.rstrip() + "\n" + after.lstrip()).rstrip() + "\n")
    print(f"removed zsh PATH shim: {target}")
PY
}

remove_zsh_path_block "$ZSHENV_PATH"
remove_zsh_path_block "$ZPROFILE_PATH"
remove_zsh_path_block "$ZSHRC_PATH"

echo "uninstall complete"
