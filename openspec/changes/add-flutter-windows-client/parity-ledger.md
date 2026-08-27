# Native destination parity ledger

The existing web frontend remains in the source tree as a compatibility surface. The installed Windows package contains no `index.html` or embedded web dashboard.

| Existing destination | OpenHUB destination | Verified native scope | Evidence |
| --- | --- | --- | --- |
| Dashboard | Overview | Fleet/account health, projections, request activity, freshness, manual refresh, and section-local failure handling | `app_smoke_test.dart`, `async_section_test.dart`, `live_contract_test.dart` |
| Accounts | Accounts | Listing/detail, OAuth/import, pause/reactivate, alias and policy edits, probes, reset credits, guarded export, and guarded deletion | `models_test.dart`, `local_api_client_test.dart`, `live_contract_test.dart` |
| Reports | Traffic | Local-time range selection, summary metrics, trends, and request-log inspection | `formatters_test.dart`, `models_test.dart`, `live_contract_test.dart` |
| APIs | API access | API-key lifecycle, one-time secret presentation, model/source access, limits, analytics, and trends | `api_key_analytics_test.dart`, `api_key_source_scope_test.dart`, `live_contract_test.dart` |
| Automations | Automations | Listing, filters, editor, run-now, run history/detail, and guarded deletion | `models_test.dart`, `local_api_client_test.dart`, `live_contract_test.dart` |
| Settings | Settings | Core appearance/auth, routing, upstream proxies, model sources, firewall, quota planner, sticky sessions, retention, and lazy advanced disclosure | `advanced_settings_widget_test.dart`, `models_test.dart`, `live_contract_test.dart` |

Cross-cutting contracts are covered by `runtime_config_test.dart`, `backend_supervisor_test.dart`, `backup_service_test.dart`, `codex_integration_test.dart`, `managed_codex_launch_test.dart`, and `performance_budget_test.dart`. The disposable-fixture live contract passed against the packaged sidecar on Windows; no credential field is represented in Dart or accepted from the tested APIs.
