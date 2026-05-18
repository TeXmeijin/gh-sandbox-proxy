#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_BIN="$ROOT_DIR/bin/gh"
WRAPPER_BIN_DIR="$(dirname "$WRAPPER_BIN")"
CONFIG_SRC="$ROOT_DIR/config.example.yml"
CONFIG_DIR="$HOME/.config/gh-sandbox-proxy"
CONFIG_FILE="$CONFIG_DIR/config.yml"
LINK_DIR="$HOME/.local/bin"
LINK_PATH="$LINK_DIR/gh"
ZSHENV_PATH="$HOME/.zshenv"
ZPROFILE_PATH="$HOME/.zprofile"
ZSHRC_PATH="$HOME/.zshrc"
IMAGE_NAME="gh-sandbox-proxy:latest"

if [[ $# -gt 0 ]]; then
  cat >&2 <<USAGE
Usage: ./install.sh

This installer is intentionally opinionated for Claude Code, Codex, and similar
coding-agent users. It always:
  - installs the gh wrapper symlink into ~/.local/bin
  - adds zsh PATH shims to ~/.zshenv, ~/.zprofile, and ~/.zshrc
  - builds the Docker image
  - verifies command resolution for interactive and non-interactive shells
USAGE
  exit 2
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

install_zsh_path_block() {
  local target_file="$1"
  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"
  WRAPPER_BIN_DIR="$WRAPPER_BIN_DIR" ZSH_TARGET="$target_file" python3 - <<'PY'
import os
from pathlib import Path

target = Path(os.environ["ZSH_TARGET"])
wrapper_bin_dir = os.environ["WRAPPER_BIN_DIR"]
begin = "# >>> gh-sandbox-proxy PATH >>>"
end = "# <<< gh-sandbox-proxy PATH <<<"
block = f"""{begin}
# Ensure coding-agent shells use gh-sandbox-proxy before Homebrew gh.
_gh_wrapper_bin={wrapper_bin_dir!r}
if [[ -d "$_gh_wrapper_bin" ]]; then
  path=("$_gh_wrapper_bin" "${{(@)path:#$_gh_wrapper_bin}}")
  export PATH
fi
unset _gh_wrapper_bin
{end}
"""

text = target.read_text() if target.exists() else ""
if begin in text and end in text:
    before, rest = text.split(begin, 1)
    _, after = rest.split(end, 1)
    text = before.rstrip() + "\n\n" + block + after
else:
    text = text.rstrip() + "\n\n" + block if text.strip() else block
target.write_text(text)
PY
  echo "installed zsh PATH shim: $target_file"
}

verify_resolution() {
  local resolved

  echo
  echo "Verify command resolution:"

  PATH="$LINK_DIR:$PATH" sh -c 'type gh'

  if command -v zsh >/dev/null 2>&1; then
    zsh -lc 'type gh'
    resolved="$(zsh -lc 'command -v gh' 2>/dev/null || true)"
    if [[ "$resolved" != "$WRAPPER_BIN" ]]; then
      echo "error: zsh -lc resolves gh to ${resolved:-not found}, expected $WRAPPER_BIN" >&2
      exit 1
    fi
    if zsh -lc 'gh auth token' >/tmp/gh-sandbox-proxy-token-check.out 2>&1; then
      cat /tmp/gh-sandbox-proxy-token-check.out >&2
      echo "error: gh auth token was not blocked" >&2
      exit 1
    fi
    if ! grep -q "blocked: this wrapper never exposes GitHub auth tokens" /tmp/gh-sandbox-proxy-token-check.out; then
      cat /tmp/gh-sandbox-proxy-token-check.out >&2
      echo "error: gh auth token did not appear to be handled by gh-sandbox-proxy" >&2
      exit 1
    fi
    rm -f /tmp/gh-sandbox-proxy-token-check.out
  fi
}

require_cmd docker
require_cmd python3

chmod +x "$WRAPPER_BIN"

mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_SRC" "$CONFIG_FILE"
  echo "created config: $CONFIG_FILE"
else
  echo "kept existing config: $CONFIG_FILE"
fi

mkdir -p "$LINK_DIR"
ln -sfn "$WRAPPER_BIN" "$LINK_PATH"
echo "installed user gh symlink: $LINK_PATH -> $WRAPPER_BIN"

install_zsh_path_block "$ZSHENV_PATH"
install_zsh_path_block "$ZPROFILE_PATH"
install_zsh_path_block "$ZSHRC_PATH"

docker build -t "$IMAGE_NAME" "$ROOT_DIR"

verify_resolution

cat <<NEXT

Install complete.

Verification commands:
  type gh
  zsh -lc 'type gh; gh auth token'
  gh auth token

Expected:
  - all command resolution points to $WRAPPER_BIN
  - gh auth token is blocked by gh-sandbox-proxy
NEXT
