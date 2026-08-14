# aibox

**Enterprise-ready Linux sandbox for AI agents and untrusted AI-generated code.**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.2.0-green.svg)](https://github.com/Pr3ndy-ctrl/aibox)

```bash
aibox run python my_agent.py
aibox run --allow-net api.openai.com,api.anthropic.com python agent.py
aibox shell
```

## Why aibox?

AI agents need to execute code, call tools, and touch the filesystem.  
Running them with full user privileges is dangerous.

`aibox` gives you:

- Strong default isolation via [bubblewrap](https://github.com/containers/bubblewrap)
- Network **denied by default**
- Optional **cooperative host allow-list** (HTTP/HTTPS proxy)
- Private empty `HOME`
- Only an explicit workspace is writable
- Clean environment (secrets not leaked by default)
- Session tracking + **JSON audit logs** (SIEM-friendly)
- systemd integration example
- Simple, auditable Bash + Python implementation

## Security model

| Feature | Default | Notes |
|---------|---------|-------|
| Mount namespace | Always | |
| PID / IPC / UTS namespaces | Yes | |
| Network | `none` | `host` or `allow` available |
| System paths | Read-only | `/usr`, `/bin`, `/lib`, … |
| HOME | Private tmpfs | Empty, no real `$HOME` |
| Workspace | Read-write | Current dir or `--workspace` |
| Environment | Clean | Opt-in with `--keep-env` |
| GPU | Denied | Opt-in with `--gpu` |
| Audit | JSON lines | `/var/log/aibox/aibox.jsonl` |

**Important:** bubblewrap shares the host kernel. For maximum isolation against kernel exploits, use microVMs (Firecracker, Kata, etc.) for high-risk multi-tenant workloads. aibox is designed for the common case of containing prompt-injection and runaway agents on a trusted host.

### Network modes

- `none` — full network namespace isolation (no connectivity)
- `host` — share host network stack (no filtering)
- `allow` — share host network + force cooperative HTTP(S) traffic through an allow-list proxy

The allow-list proxy is **cooperative**: clients must honour `HTTP_PROXY` / `HTTPS_PROXY`. Most language HTTP libraries and tools (`curl`, `wget`, Python `requests`/`httpx`, Node `fetch` with proxy support, etc.) do.

## Requirements

- Linux with user namespaces enabled
- `bubblewrap` (`bwrap`)
- Bash 4+
- Python 3 (only required for `--allow-net` / `--net allow`)

## Install

### From source

```bash
git clone https://github.com/Pr3ndy-ctrl/aibox.git
cd aibox
sudo ./scripts/install.sh
```

### Debian / Ubuntu package

```bash
# Build
./scripts/build-deb.sh

# Install
sudo dpkg -i dist/aibox_0.2.0_all.deb
sudo apt-get install -f   # if needed for dependencies
```

## Quick start

```bash
# Safest default
aibox run python my_agent.py

# Interactive shell
aibox shell

# Allow only specific API hosts
aibox run --allow-net api.openai.com,api.anthropic.com,api.github.com \
  python agent.py

# GPU + custom workspace + JSON logs
aibox run --gpu -w /data/jobs --json train.py

# Inspect posture
aibox info
aibox list
```

## Configuration

System: `/etc/aibox/aibox.conf`  
User: `~/.config/aibox/aibox.conf`

```
network_mode=none
allow_gpu=false
log_to_file=true
keep_env=false
use_landlock=true
# allow_hosts=api.openai.com,api.anthropic.com
```

## Logging & SIEM

With default settings (or `--json`):

- Human-readable session logs under the state directory
- Structured JSON lines in `/var/log/aibox/aibox.jsonl` (or `~/.local/share/aibox/logs/`)

Example event:

```json
{"event":"session_start","ts":"2026-08-14T21:20:00Z","tool":"aibox","version":"0.2.0","sid":"aibox-...","pid":"1234","net":"allow","gpu":"false","cmd":"python agent.py"}
```

## systemd

See `systemd/aibox@.service` for a template to run long-lived agents under aibox.

## Project layout

```
aibox/
├── bin/aibox              # Main CLI
├── lib/aibox-proxy.py     # Allow-list HTTP CONNECT proxy
├── etc/aibox.conf         # Default config
├── scripts/
│   ├── install.sh
│   └── build-deb.sh
├── systemd/aibox@.service
├── packaging/             # Deb scaffolding
├── docs/
├── LICENSE                # Apache-2.0
└── README.md
```

## Roadmap

- [ ] Stronger Landlock integration (native helper)
- [ ] Optional seccomp profiles
- [ ] cgroup resource limits
- [ ] Official packages beyond .deb
- [ ] Non-cooperative network enforcement (eBPF / nftables helper)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: please open a private advisory or email the maintainer.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Copyright 2026 [Pr3ndy-ctrl](https://github.com/Pr3ndy-ctrl)
