# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path
import sys

from PyInstaller.utils.hooks import collect_data_files, collect_submodules


project_root = Path(SPECPATH).resolve().parents[1]

project_root_text = str(project_root)
if project_root_text not in sys.path:
    sys.path.insert(0, project_root_text)

app_hidden_imports = [
    module
    for module in collect_submodules("app")
    if module != "app.codex_sessions_retag"
]

hidden_imports = sorted(
    set(
        app_hidden_imports
        + collect_submodules("aiosqlite")
        + [
            "sqlalchemy.dialects.sqlite.aiosqlite",
            "uvicorn.lifespan.on",
            "uvicorn.logging",
            "uvicorn.loops.auto",
            "uvicorn.protocols.http.auto",
            "uvicorn.protocols.websockets.auto",
        ]
    )
)

# Keep optional interactive, test, notebook, and GUI stacks out of the pinned
# backend even when a contributor has installed them in the project environment.
excluded_modules = [
    "IPython",
    "PIL",
    "PyQt5",
    "PyQt6",
    "PySide2",
    "PySide6",
    "_pytest",
    "jedi",
    "jupyter",
    "matplotlib",
    "notebook",
    "numpy",
    "pandas",
    "parso",
    "py",
    "pytest",
    "tkinter",
    "zmq",
    "app.codex_sessions_retag",
]

datas = [
    (str(project_root / "app" / "db" / "alembic"), "app/db/alembic"),
    (
        str(project_root / "app" / "modules" / "oauth" / "templates"),
        "app/modules/oauth/templates",
    ),
    (
        str(project_root / "config" / "additional_quota_registry.json"),
        "config",
    ),
]
datas += collect_data_files("certifi")

a = Analysis(
    [str(project_root / "scripts" / "native_windows" / "backend_entry.py")],
    pathex=[str(project_root)],
    binaries=[],
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excluded_modules,
    noarchive=False,
    optimize=1,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="openhub-backend",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="openhub-backend",
)
