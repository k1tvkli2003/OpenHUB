# Getting Started

OpenHUB runs locally with safe defaults and auto-detects its host paths.

## Quick Start

On Windows, download and extract `OpenHUB-Windows-2.0.0.zip` from the latest
GitHub Release, then run `Launch-OpenHUB.ps1`. The archive includes the pinned
backend and native Flutter dashboard, and does not resolve packages at startup.
The OpenHUB window opens automatically; add an account there and continue to
[Client Setup](client-setup.md).

To run the backend from source:

```bash
git clone https://github.com/k1tvkli2003/OpenHUB.git
cd OpenHUB
uv sync --frozen
uv run openhub
```

When running the backend from source (or from the container image), open
[localhost:2455](http://localhost:2455) to use the optional web dashboard.

Next: point your coding agent at openhub — see [Client Setup](client-setup.md).

## Remote setup (bootstrap token)

When accessing the dashboard remotely for the first time, a bootstrap token is required to set the initial password.

**Auto-generated (default):** On first startup (no password configured), the server generates a one-time token and prints it to logs:

```text
# Read the process console output.
# ============================================
#   Dashboard bootstrap token (first-run):
#   <token>
# ============================================
```

Open the dashboard → enter the token + new password → done. The token is shared across replicas and remains valid until a password is set. In multi-replica setups, replicas must share the same encryption key (the Helm chart default) for restart recovery to work — see [Kubernetes deployment](deployment/kubernetes.md).

**Manual token:** To use a fixed token instead, set the env var before starting:

```powershell
$env:OPENHUB_DASHBOARD_BOOTSTRAP_TOKEN = 'replace-with-a-secret'
uv run openhub
```

**Local access** (localhost) bypasses bootstrap entirely — no token needed.

Running behind a reverse proxy or exposing openhub to other machines? See [Remote Access](deployment/remote.md) and [Authentication](authentication.md).

---

*Spec: [deployment-installation](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/deployment-installation)*
