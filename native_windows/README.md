# OpenHUB for Windows

This Flutter client is the native OpenHUB operator surface. It starts a pinned local backend sidecar, discovers Codex, Hermes Agent, and OpenCode, and renders their task/model/token state in Pulse.

## Local development

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

The default data directory is `%USERPROFILE%\.openhub`. Override it only for disposable tests with `OPENHUB_DATA_DIR`; never point a fixture at a real account store.

## Release build

From the repository root:

```powershell
./scripts/native_windows/Build-NativeWindowsPackage.ps1
```

The script builds `OpenHUB.exe`, a pinned `openhub-backend.exe`, launch scripts, license, package metadata, and SHA-256 manifests into `native_windows/dist/OpenHUB-Windows-2.0.0.zip`.

The existing route-hub logo is the canonical app icon and must not be replaced during packaging.
