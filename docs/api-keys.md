# API Key Authentication

API key auth is **disabled by default**. In that mode, only local requests to the protected proxy routes can
proceed without a key; non-local requests are rejected until proxy authentication is configured. Enable it in
**Settings → API Key Auth** on the dashboard when clients connect remotely or through Docker, VM, or container
networking that appears non-local to the service.

When enabled, clients must pass a valid API key as a Bearer token:

```
Authorization: Bearer sk-openhub-...
```

## Protected routes

The protected proxy routes covered by this setting are:

- `/v1/*` (except `/v1/usage`, which always requires a valid key)
- `/backend-api/codex/*`
- `/backend-api/transcribe`

## Creating keys

Dashboard → API Keys → Create. The full key is shown **only once** at creation. Keys support optional expiration, model restrictions, and rate limits (tokens / cost per day / week / month).

Keys can also be scoped to specific accounts, so a key draws quota only from
the accounts assigned to it. New keys use the `sk-openhub-` prefix. Existing
`sk-clb-` keys issued by older builds remain valid and do not need migration;
regenerating one produces a new OpenHUB-prefixed secret.

For wiring keys into each client, see [Client Setup](client-setup.md).

---

*Spec: [api-keys](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/api-keys)*
