# Contributing to aibox

Thanks for your interest in improving aibox.

## Principles

1. **Security first** — changes that weaken isolation need strong justification and documentation.
2. **Auditable** — prefer simple, readable Bash/Python over cleverness.
3. **No silent privilege** — defaults must stay restrictive.
4. **Enterprise usable** — clear exit codes, logging, and packaging matter.

## Development setup

```bash
git clone https://github.com/Pr3ndy-ctrl/aibox.git
cd aibox
# Needs bubblewrap
sudo apt install bubblewrap   # or equivalent
bash bin/aibox version
bash bin/aibox run echo ok
```

## Testing

Manual smoke tests:

```bash
bash bin/aibox run echo hello
bash bin/aibox run cat /etc/shadow          # must fail / not exist
bash bin/aibox run curl https://example.com # must fail with net=none
bash bin/aibox run --allow-net example.com curl -sI https://example.com
bash bin/aibox run --json echo test
```

## Pull requests

- Keep diffs focused
- Update README / docs when behaviour changes
- Do not commit secrets or personal paths
- Sign commits if you can

## License

By contributing you agree that your contributions are licensed under the Apache License 2.0.
