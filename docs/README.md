# aibox

**Enterprise-ready Linux sandbox for AI agents and untrusted AI-generated code.**

Version 0.1.0

## Why aibox?

AI agents frequently need to execute code, call tools, and touch the filesystem.
Running them with full user privileges is dangerous.

Existing tools (Docker, Firejail, plain bubblewrap scripts) are either heavy, require root, or lack AI-specific defaults and operational features.

**aibox** provides:

- Strong default isolation using bubblewrap (unprivileged namespaces)
- Network denied by default
- Private empty HOME
- Only an explicit workspace is writable
- Clean environment (secrets not leaked by default)
- Session tracking + audit logging
- Simple, consistent CLI
- Configuration files for enterprise policy
- systemd integration example

## Security Model (v0.1)

| Feature                    | Default          | Notes                                      |
|---------------------------|------------------|--------------------------------------------|
| Mount namespace            | Always           |                                            |
| PID namespace              | Yes              |                                            |
| IPC namespace              | Yes              |                                            |
| Network namespace          | Yes (`none`)     | Use `--net host` only when required        |
| System paths              | Read-only        | `/usr`, `/bin`, `/lib`, …                  |
| HOME                      | Private tmpfs    | Empty, no access to real `$HOME`           |
| Workspace                 | Read-write       | Current dir or `--workspace`               |
| Environment               | Clean            | Only safe + explicit API keys passed       |
| die-with-parent           | Yes              |                                            |
| new-session               | Yes              |                                            |
| GPU devices               | Denied           | Opt-in with `--gpu`                        |

**Important**: bubblewrap shares the host kernel. For maximum isolation against kernel exploits, consider microVMs (Firecracker, Kata, etc.) for high-risk workloads. aibox is designed for the common case of containing prompt-injection / runaway agents.

## Requirements

- Linux with user namespaces enabled (most modern distros)
- `bubblewrap` (`bwrap`) installed
- Bash 4+

## Installation

```bash
# From the project root
sudo ./scripts/install.sh

# Or manually
sudo install -m 0755 bin/aibox /usr/local/bin/aibox
sudo mkdir -p /etc/aibox
sudo cp etc/aibox.conf /etc/aibox/
```

## Quick Start

```bash
# Safest possible run
aibox run python my_agent.py

# Interactive shell inside the sandbox
aibox shell

# Allow network (still filesystem-isolated)
aibox run --net host ollama run llama3

# GPU + custom workspace
aibox run --gpu -w /data/jobs train.py

# See what would be executed
aibox run --dry-run --net none echo hello

# List / kill sessions
aibox list
aibox kill aibox-20260814-221500-12345-6789
```

## Configuration

System-wide: `/etc/aibox/aibox.conf`  
User: `~/.config/aibox/aibox.conf`  
Or `AIBOX_CONFIG=/path/to/file`

Example:

```
network_mode=none
allow_gpu=false
log_to_file=true
keep_env=false
```

## Logging & Audit

- Session metadata written to `$XDG_RUNTIME_DIR/aibox/` (or `/tmp/aibox`)
- Audit log (start/end) written to `/var/log/aibox/aibox.log` (falls back to user dir if not writable)

## Enterprise Notes

- Run agents under a dedicated low-privilege user when possible.
- Combine with systemd (see `systemd/aibox@.service`) for long-running agents.
- Use `--ro` for shared model caches / datasets.
- Prefer `--net none` and inject only required API keys.
- Rotate logs and clean old session files via cron or logrotate.
- For multi-tenant hosts, consider additional Landlock or seccomp layers in future versions.

## Roadmap (future)

- Network allow-list via userspace proxy (no root required)
- Landlock second layer
- cgroup resource limits integration
- JSON output / machine-readable status
- Official packages (deb/rpm)
- Optional Firejail / gVisor backends

## License

Apache-2.0
