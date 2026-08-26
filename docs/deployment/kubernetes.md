# Kubernetes

Build chart dependencies and install from this repository:

```bash
helm dependency build deploy/helm/openhub
helm install openhub deploy/helm/openhub \
  --set postgresql.auth.password=changeme \
  --set config.databaseMigrateOnStartup=true \
  --set migration.schemaGate.enabled=false
kubectl port-forward svc/openhub 2455:2455
```

Open [localhost:2455](http://localhost:2455) → Add account → Done.

## Multi-replica behavior

The Helm chart auto-configures HTTP `/responses` owner handoff for multi-replica installs using a headless-service DNS name per pod. The default cluster domain is `cluster.local`; set Helm `clusterDomain` if your cluster uses a different suffix. Override `config.sessionBridgeAdvertiseBaseUrl` only if pods must be reached through a different internal address.

In multi-replica setups, replicas must share the same encryption key (the Helm chart default) for bootstrap-token restart recovery and encrypted-data access to work.

## Gateway API path filters

Set `gatewayApi.rules` when different request paths need different Gateway API
filters. The chart renders each rule's `matches` and `filters` in order and
adds the openhub Service backend automatically. For example, this keeps API
traffic direct while applying a Traefik forward-auth middleware to the
dashboard catch-all:

```yaml
gatewayApi:
  enabled: true
  parentRefs:
    - name: gateway
      namespace: gateway-system
  hostnames:
    - openhub.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1
        - path:
            type: PathPrefix
            value: /backend-api/codex
        - path:
            type: PathPrefix
            value: /backend-api/wham
        - path:
            type: PathPrefix
            value: /backend-api/transcribe
        - path:
            type: PathPrefix
            value: /backend-api/files
        - path:
            type: PathPrefix
            value: /api/codex
    - matches:
        - path:
            type: PathPrefix
            value: /
      filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: oauth-forward-auth
```

The default empty `rules` list preserves the chart's catch-all HTTPRoute.
Keep `/backend-api/wham`, `/backend-api/files`, and `/api/codex` in the
unfiltered API rule: WHAM identity discovery, file uploads, and Codex
usage/reset-credit calls authenticate independently of the dashboard's
forward-auth middleware.
Extension resources must be valid for the release namespace according to the
Gateway implementation.

## Full chart reference

For external database, production config, ingress, observability, and more see the
[Helm chart README](https://github.com/k1tvkli2003/OpenHUB/blob/main/deploy/helm/openhub/README.md).

---

*Specs: [deployment-installation](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/deployment-installation) · [deployment-networking](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/deployment-networking) · [replica-operations](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/replica-operations)*
