import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('stable and package launchers forward managed launch intent', () {
    final sourceRoot = path.basename(Directory.current.path) == 'native_windows'
        ? Directory.current.parent.path
        : Directory.current.path;
    final scripts = path.join(sourceRoot, 'scripts', 'native_windows');
    final packageLauncher = File(
      path.join(scripts, 'Launch-OpenHUB.ps1'),
    ).readAsStringSync();
    final stableLauncher = File(
      path.join(scripts, 'Launch-InstalledOpenHUB.ps1'),
    ).readAsStringSync();
    final installer = File(
      path.join(scripts, 'Install-OpenHUB.ps1'),
    ).readAsStringSync();
    final packageBuilder = File(
      path.join(scripts, 'Build-NativeWindowsPackage.ps1'),
    ).readAsStringSync();
    final cmake = File(
      path.join(sourceRoot, 'native_windows', 'windows', 'CMakeLists.txt'),
    ).readAsStringSync();
    final resources = File(
      path.join(sourceRoot, 'native_windows', 'windows', 'runner', 'Runner.rc'),
    ).readAsStringSync();

    expect(packageLauncher, contains(r'[switch]$LaunchCodex'));
    expect(packageLauncher, contains("@('--launch-codex')"));
    expect(stableLauncher, contains(r'-LaunchCodex:$LaunchCodex'));
    expect(installer, contains('OpenHUB - Open Codex.lnk'));
    expect(installer, contains('OpenHUB Auto Start.lnk'));
    expect(installer, contains('Localhost Dashboard Auto Start.lnk'));
    expect(
      installer,
      contains(r'foreach ($startupShortcut in $startupShortcuts)'),
    );
    expect(
      installer,
      contains(r'Remove-Item -LiteralPath $startupShortcut -Force'),
    );
    expect(installer, contains(r'$managedShortcutArguments'));
    expect(installer, contains(r'$hubShortcutArguments'));
    expect(packageLauncher, contains("'OpenHUB.exe'"));
    expect(installer, contains("'OpenHUB.exe'"));
    expect(packageBuilder, contains("'OpenHUB.exe'"));
    expect(cmake, contains('set(BINARY_NAME "OpenHUB")'));
    expect(resources, contains('"OriginalFilename", "OpenHUB.exe"'));
    for (final contract in <String>[
      packageLauncher,
      installer,
      packageBuilder,
      cmake,
      resources,
    ]) {
      expect(contract, isNot(contains('openhub_windows.exe')));
    }
    expect(installer, contains('STARTUP_SHORTCUT=disabled'));
    expect(
      installer,
      isNot(contains(r'Set-OpenHubShortcut -ShortcutPath $startupShortcut')),
    );
    expect(
      installer,
      isNot(
        contains(
          'Start OpenHUB at Windows sign-in without opening or changing Codex.',
        ),
      ),
    );
    expect(installer, isNot(contains('uvx --upgrade')));
    expect(
      installer,
      isNot(
        contains(
          "\$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Localhost Dashboard Auto Start.lnk'",
        ),
      ),
    );
  });
}
