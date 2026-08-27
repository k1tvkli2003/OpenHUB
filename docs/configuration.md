# Configuration

openhub runs with zero configuration — every setting has a working default, and container vs. host environments are auto-detected. Configure only what a docs page for your scenario tells you to.

Settings are environment variables with the `OPENHUB_` prefix, or a `.env.local` file next to the process. The commented sample lives at [`.env.example`](https://github.com/k1tvkli2003/OpenHUB/blob/main/.env.example).

## The settings that matter

| Variable | Default | When to set it |
|----------|---------|----------------|
| `OPENHUB_DATA_DIR` | `~/.openhub` (host) / `/var/lib/openhub` (Docker) | Move the data directory (DB, encryption key, archives) |
| `PORT` | `2455` | Change the listen port on host (uvx/local) runs — process environment only, not `.env.local` (env files map only `OPENHUB_`-prefixed variables). In Docker the container always listens on 2455 (the entrypoint pins `--port 2455`); change the host side of the compose `ports` mapping instead (e.g. `"8080:2455"`) |
| `OPENHUB_DATABASE_URL` | SQLite in the data dir | Use PostgreSQL — see [Database](database.md) |
| `OPENHUB_ENCRYPTION_KEY_FILE` | auto-generated in the data dir | Pin the key location (recommended for Docker volumes and required to be shared across replicas) |
| `OPENHUB_DASHBOARD_AUTH_MODE` | `standard` | `trusted_header` / `disabled` — see [Authentication](authentication.md) |
| `OPENHUB_FIREWALL_TRUST_PROXY_HEADERS` | `false` | Behind a reverse proxy — see [Remote Access](deployment/remote.md) |
| `OPENHUB_FIREWALL_TRUSTED_PROXY_CIDRS` | `127.0.0.1/32,::1/128` | CIDRs allowed to set `X-Forwarded-For` |
| `OPENHUB_OAUTH_CALLBACK_HOST` | auto-detected (`0.0.0.0` in containers) | Rarely — bind the OAuth login callback explicitly |

## Everything else

The remaining settings (timeouts, connection pools, bulkheads, session bridge, leader election, observability, circuit breakers, ...) are advanced operational tunables with tested defaults. The full generated [settings reference](reference/settings.md) lists every variable with its type and default. Do not tune them unless the documentation for your specific scenario says so:

- [Deployment on Kubernetes / multi-replica](deployment/kubernetes.md)
- [Remote access and reverse proxies](deployment/remote.md)
- [Database backends](database.md)
- [Troubleshooting](troubleshooting.md)

Runtime behavior such as the routing strategy, upstream stream transport, and per-account limits is configured live in the dashboard under **Settings** — no restart required.

---

*Specs: [deployment-installation](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/deployment-installation) · [replica-operations](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/replica-operations)*
