---
name: gh-sandbox-proxy-installer
description: Install, verify, update, or uninstall the gh-sandbox-proxy wrapper so GitHub CLI auth runs inside Docker and host `gh auth token` is blocked. Use when a user asks to set up the safer gh wrapper, distribute it to a machine, fix Claude Code PATH issues for gh, or revert the wrapper.
---

# gh-sandbox-proxy installer

Use this skill to install or maintain `gh-sandbox-proxy`, a wrapper that proxies
`gh` commands into a Docker sandbox while blocking host-side token printing.

## Default install workflow

1. Locate or clone the `gh-sandbox-proxy` repository.
2. Inspect the machine's likely repository roots and propose stable ancestor
   directories for `workspace_mounts`. Prefer roots such as `~/ghq`,
   `~/Documents/src`, or another directory that contains many git repositories.
   Do not suggest mounting `$HOME` unless the user explicitly accepts the wider
   access.
3. Run:

```bash
./install.sh
```

4. If the user accepted workspace roots, edit
   `~/.config/gh-sandbox-proxy/config.yml` and set:

```yaml
workspace_mounts:
  - ~/ghq
  - ~/Documents/src
```

5. Verify:

```bash
which gh
gh auth token
gh --version
gh sandbox status
```

Expected:

- `which gh` points to `~/.local/bin/gh` or another installed wrapper path.
- `gh auth token` is blocked by `gh-sandbox-proxy`.
- `gh --version` proxies to the official GitHub CLI inside Docker.
- `gh sandbox status` shows a `container_workdir` when run under a configured
  workspace mount.

Use this helper to list initial candidates:

```bash
gh sandbox suggest-mounts
```

## Claude Code PATH issue

If Claude Code or another agent still resolves `/usr/local/bin/gh` or the
official `gh`, prefer the non-interactive zsh shim first:

```bash
./install.sh --zshenv
```

Then verify:

```bash
type gh
zsh -lc 'type gh; gh auth status'
gh auth status
```

If the shell still resolves the official `gh`, use the stronger fallback:

```bash
./install.sh --system-link
```

This backs up the existing `/usr/local/bin/gh` once and replaces it with a
symlink to the wrapper.

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
