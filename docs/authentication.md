# Authentication

This page covers **dashboard** authentication. For protecting the proxy routes that clients call, see [API Keys](api-keys.md).

## Dashboard authentication modes

`openhub` supports three dashboard auth modes via environment variables:

- `OPENHUB_DASHBOARD_AUTH_MODE=standard` — built-in dashboard password with optional TOTP from the Settings page. This is the default.
- `OPENHUB_DASHBOARD_AUTH_MODE=trusted_header` — trust a reverse-proxy auth header such as Authelia's `Remote-User`, but only from `OPENHUB_FIREWALL_TRUSTED_PROXY_CIDRS`. Built-in password/TOTP remain available as an optional fallback, and password/TOTP management still requires a fallback password session.
- `OPENHUB_DASHBOARD_AUTH_MODE=disabled` — fully bypass dashboard auth. Use only behind network restrictions or external auth. Built-in password/TOTP management is disabled in this mode.

`trusted_header` mode also requires:

```bash
OPENHUB_FIREWALL_TRUST_PROXY_HEADERS=true
OPENHUB_FIREWALL_TRUSTED_PROXY_CIDRS=172.18.0.0/16
OPENHUB_DASHBOARD_AUTH_PROXY_HEADER=Remote-User
```

If the trusted header is missing and no fallback password is configured, the dashboard fails closed and shows a reverse-proxy-required message instead of loading the UI.

Ready-to-run Docker commands for both non-default modes are in [Docker deployment — auth mode examples](deployment/docker.md#auth-mode-examples). For Helm, pass the same values through `extraEnv`.

## First-time remote access

Setting the initial dashboard password from a remote machine requires a one-time bootstrap token — see [Getting Started](getting-started.md#remote-setup-bootstrap-token).

---

*Specs: [admin-auth](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/admin-auth) · [api-firewall](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/api-firewall)*
