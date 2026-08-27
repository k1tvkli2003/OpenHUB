from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

pytestmark = pytest.mark.unit

ROOT = Path(__file__).resolve().parents[2]


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _publishable_text() -> str:
    roots = (
        ROOT / "docs",
        ROOT / "frontend" / "src",
        ROOT / "frontend" / "public",
        ROOT / "native_windows" / "lib",
        ROOT / "app" / "modules" / "oauth" / "templates",
        ROOT / "scripts" / "native_windows",
        ROOT / ".github" / "workflows",
        ROOT / "deploy" / "helm" / "openhub",
    )
    suffixes = {
        ".css",
        ".dart",
        ".html",
        ".json",
        ".md",
        ".ps1",
        ".py",
        ".svg",
        ".ts",
        ".tsx",
        ".yaml",
        ".yml",
    }
    return "\n".join(
        path.read_text(encoding="utf-8")
        for root in roots
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in suffixes
    )


def test_approved_logo_and_selected_wordmark_are_identical_across_surfaces() -> None:
    logo_paths = (
        ROOT / "native_windows" / "assets" / "brand" / "openhub-route-hub.png",
        ROOT / "docs" / "assets" / "brand" / "openhub-route-hub.png",
        ROOT / "frontend" / "public" / "openhub-route-hub.png",
        ROOT / "app" / "modules" / "oauth" / "templates" / "openhub-route-hub.png",
    )
    wordmark_paths = (
        ROOT / "native_windows" / "assets" / "brand" / "openhub-wordmark.png",
        ROOT / "docs" / "assets" / "brand" / "openhub-wordmark.png",
        ROOT / "frontend" / "public" / "openhub-wordmark.png",
        ROOT / "app" / "modules" / "oauth" / "templates" / "openhub-wordmark.png",
    )

    assert len({_sha256(path) for path in logo_paths}) == 1
    assert len({_sha256(path) for path in wordmark_paths}) == 1
    assert all(
        path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
        for path in (*logo_paths, *wordmark_paths)
    )


def test_publishable_surfaces_do_not_regress_to_upstream_identity() -> None:
    public_text = _publishable_text()
    forbidden = (
        "Codex LB",
        "Codex-LB",
        "CodexHUB",
        "CodexLogo",
        "oci://ghcr.io/soju06/charts/openhub",
        "ghcr.io/k1tvkli2003/openhub:latest",
    )

    for value in forbidden:
        assert value not in public_text


def test_pages_and_oauth_use_current_assets_without_legacy_screenshots() -> None:
    assert not (ROOT / "docs" / "screenshots").exists()
    mkdocs = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
    homepage = (ROOT / "docs" / "index.md").read_text(encoding="utf-8")
    callback = (ROOT / "app" / "modules" / "oauth" / "templates" / "oauth_success.html").read_text(
        encoding="utf-8"
    )
    callback_server = (ROOT / "app" / "modules" / "oauth" / "service.py").read_text(
        encoding="utf-8"
    )

    assert "logo: assets/brand/openhub-route-hub.png" in mkdocs
    assert "favicon: assets/brand/openhub-route-hub.png" in mkdocs
    assert 'src="assets/brand/openhub-wordmark.png"' in homepage
    assert 'src="/openhub-route-hub.png"' in callback
    assert 'src="/openhub-wordmark.png"' in callback
    assert 'app.router.add_get("/openhub-route-hub.png", self._brand_logo)' in callback_server
    assert 'app.router.add_get("/openhub-wordmark.png", self._brand_wordmark)' in callback_server
    assert "official Codex OAuth client" in homepage


def test_docs_do_not_claim_unpublished_container_or_chart() -> None:
    docker = (ROOT / "docs" / "deployment" / "docker.md").read_text(encoding="utf-8")
    kubernetes = (ROOT / "docs" / "deployment" / "kubernetes.md").read_text(encoding="utf-8")
    helm = (ROOT / "deploy" / "helm" / "openhub" / "README.md").read_text(encoding="utf-8")
    values = (ROOT / "deploy" / "helm" / "openhub" / "values.yaml").read_text(encoding="utf-8")

    assert "docker build -t openhub:local ." in docker
    assert "docker build -t openhub:local ." in kubernetes
    assert "does not publish a public container image or OCI chart" in helm
    assert "helm install openhub deploy/helm/openhub" in helm
    assert 'registry: ""' in values
    assert "repository: openhub" in values
    assert "tag: local" in values


def test_readme_thanks_upstream_project_and_contributors() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")

    assert "License, provenance, and thanks" in readme
    assert "https://github.com/Soju06/codex-lb" in readme
    assert "https://github.com/Soju06/codex-lb/graphs/contributors" in readme


def test_retired_provider_switcher_and_ox_adapter_are_not_shipped() -> None:
    public_text = _publishable_text()
    codex_api = (ROOT / "app" / "modules" / "codex_integration" / "api.py").read_text(
        encoding="utf-8"
    )
    pubspec = (ROOT / "native_windows" / "pubspec.yaml").read_text(encoding="utf-8")

    assert "Ox adapter telemetry" not in public_text
    assert "Switching uses the existing atomic provider switcher" not in public_text
    assert '"/profiles"' not in codex_api
    assert "/profiles/{profile_id}" not in codex_api
    assert "assets/ox/" not in pubspec
    ox_assets = ROOT / "native_windows" / "assets" / "ox"
    assert not ox_assets.exists() or not any(ox_assets.iterdir())
    assert not (
        ROOT / "native_windows" / "lib" / "src" / "core" / "runtime" / "ox_bridge_supervisor.dart"
    ).exists()
    assert not (ROOT / "app" / "modules" / "codex_integration" / "profiles.py").exists()
