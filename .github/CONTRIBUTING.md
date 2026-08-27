# Contributing to OpenHUB

Thanks for helping improve OpenHUB. The project accepts focused fixes,
documentation improvements, tests, runtime adapters, and carefully scoped
features.

## Development setup

Install Python 3.13, `uv`, Bun 1.3.14, Flutter 3.44.0, and Visual Studio Build
Tools with the Windows C++ desktop workload.

```powershell
uv sync --dev --frozen
uv run ruff check app tests scripts
uv run pytest tests/unit -q

Set-Location frontend
bun install --frozen-lockfile
bun run lint
bun run typecheck
bun run test
bun run build

Set-Location ../native_windows
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

Validate shipped requirements and any active change you are editing:

```powershell
npm exec --yes --package=@fission-ai/openspec@1.10.0 -- openspec validate --specs --strict
$changeName = 'replace-with-your-change-name'
npm exec --yes --package=@fission-ai/openspec@1.10.0 -- openspec validate $changeName --type change --strict
```

## Project layout

- `app/`: FastAPI control plane, account router, federation, and runtime APIs.
- `frontend/`: browser dashboard bundled into the Python service.
- `native_windows/`: Flutter Windows operator client.
- `scripts/native_windows/`: reproducible portable-package tooling.
- `openspec/`: behavioral requirements and change records.
- `tests/`: backend unit, integration, end-to-end, and load tests.

## Pull requests

Keep each pull request coherent and use a Conventional Commit-style title such
as `fix(router): isolate account cooldown` or
`feat(pulse): add a runtime adapter`.

Before requesting review:

1. describe the user-visible behavior and safety boundary;
2. add or update an OpenSpec delta when behavior changes;
3. add regression tests;
4. run the relevant local gates above;
5. do not include credentials, runtime stores, generated packages, or personal
   `.codex`, Hermes, OpenCode, or `.openhub` data.

The GitHub CI runs backend lint/tests, dashboard lint/typecheck/tests/build,
Flutter analysis/tests/Windows build, and strict shipped-contract validation.

## Release process

Every accepted push to `main` creates a unique run-numbered beta Windows
release. A maintainer may manually dispatch the release workflow with an exact
`X.Y.Z` or prerelease version. Release jobs are serialized and never cancel an
in-progress publication.

The workflow:

1. tests backend and native client code;
2. builds the self-contained Windows archive with a pinned backend;
3. generates SHA-256 checksums and an SPDX SBOM;
4. creates an immutable tag and GitHub Release;
5. publishes a GitHub artifact provenance attestation.

Windows artifacts are currently unsigned. Do not describe a build as signed or
notarized unless a future workflow adds and verifies that step.

## Security

Do not open a public issue for a vulnerability. Follow
[SECURITY.md](SECURITY.md) and use GitHub private vulnerability reporting.
