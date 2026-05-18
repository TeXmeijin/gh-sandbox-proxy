---
name: gh-sandbox-proxy-installer
description: Install, verify, update, or uninstall the gh-sandbox-proxy wrapper for Claude Code, Codex, or similar coding-agent users so GitHub CLI auth runs inside Docker and host `gh auth token` is blocked. Use when a user asks to set up the safer gh wrapper, distribute it to a machine, fix agent PATH issues for gh, or revert the wrapper.
---

# gh-sandbox-proxy installer

Use this skill to install or maintain `gh-sandbox-proxy`, a wrapper for
developers who let Claude Code, Codex, or similar coding agents run local shell
commands. It proxies `gh` commands into a Docker sandbox while blocking
host-side token printing.

## Install workflow

1. Locate or clone the `gh-sandbox-proxy` repository.
2. Inspect the machine's likely repository roots and choose stable ancestor
   directories for `workspace_mounts`. Prefer roots such as `~/ghq`,
   `~/Documents/src`, or another directory that contains many git repositories.
   Do not mount `$HOME`. If no safe shared root exists, use the current project
   root and report the limitation.
3. Run:

```bash
./install.sh
```

The installer is intentionally not configurable. It always installs the wrapper
symlink, zsh PATH shims, builds the Docker image, and runs command-resolution
checks.

4. Edit `~/.config/gh-sandbox-proxy/config.yml` and set the selected roots:

```yaml
workspace_mounts:
  - ~/ghq
  - ~/Documents/src
```

5. Verify:

```bash
type gh
zsh -lc 'type gh; gh auth token'
gh auth token
gh --version
gh sandbox status
```

Expected:

- `type gh` and `zsh -lc 'type gh'` both resolve the wrapper path.
- `gh auth token` is blocked by `gh-sandbox-proxy`.
- `gh --version` proxies to the official GitHub CLI inside Docker.
- `gh sandbox status` shows a `container_workdir` when run under a configured
  workspace mount.

Use this helper to list initial candidates:

```bash
gh sandbox suggest-mounts
```

If `zsh -lc` resolves the official `gh`, treat the install as failed and inspect
`~/.zshenv`, shell startup files, and the agent process environment before
continuing. Do not leave a machine in a split state where terminal shells use the
wrapper but coding agents use the official `gh`.

## Uninstall

Run:

```bash
./uninstall.sh
```

This removes wrapper symlinks, restores the backed-up `/usr/local/bin/gh` when
present, and removes the active Docker sandbox container.

## Safety notes

- Do not copy host `~/.config/gh` or host GitHub tokens into the sandbox.
- Do not bypass the wrapper by calling `gh auth token`.
- Keep `workspace_mounts` as narrow as practical. Mounting a broad ancestor
  improves convenience but also gives container commands read/write access to
  that tree.
- For complete GitHub-side OAuth revocation, instruct the user to revoke GitHub
  CLI access in GitHub application settings. Local logout alone is not revoke.
