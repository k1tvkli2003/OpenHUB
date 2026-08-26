from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.modules.openhub_integration.service import OpenHubIntegrationError, integration_snapshot


def test_shared_endpoint_is_client_neutral_and_reports_parallel_limits() -> None:
    settings = SimpleNamespace(
        proxy_response_create_limit=256,
        proxy_account_response_create_limit=4,
        proxy_account_stream_limit=8,
        bulkhead_proxy_limit=512,
    )
    snapshot = integration_snapshot("http://127.0.0.1:2455/", settings=settings)

    assert snapshot.shared_base_url == "http://127.0.0.1:2455/backend-api/openhub/v1"
    assert snapshot.chatgpt_base_url == "http://127.0.0.1:2455/backend-api/openhub"
    assert snapshot.models_url.endswith("/v1/models")
    assert snapshot.limits.global_response_creates == 256
    assert snapshot.limits.per_account_response_creates == 4
    assert snapshot.limits.per_account_streams == 8
    assert snapshot.limits.proxy_requests == 512


@pytest.mark.parametrize(
    "endpoint",
    [
        "https://127.0.0.1:2455",
        "http://localhost:2455",
        "http://192.0.2.1:2455",
        "http://127.0.0.1",
        "http://user:pass@127.0.0.1:2455",
    ],
)
def test_shared_endpoint_rejects_non_numeric_or_non_loopback_inputs(endpoint: str) -> None:
    with pytest.raises(OpenHubIntegrationError):
        integration_snapshot(endpoint)
