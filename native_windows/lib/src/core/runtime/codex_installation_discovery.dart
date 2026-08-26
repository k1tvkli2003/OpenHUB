import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

typedef CodexDiscoveryPowerShellRunner =
    Future<ProcessResult> Function(String script);
typedef CodexCliResolver = Future<File> Function();

class CodexInstallationDiscoveryException implements Exception {
  const CodexInstallationDiscoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CodexInstallation {
  const CodexInstallation({
    required this.desktopVersion,
    required this.desktopExecutable,
    required this.desktopApplicationId,
    required this.asarFile,
    required this.cliExecutable,
    required this.canonicalCodexHome,
    required this.supportsAppServerWebSocket,
    required this.supportsManagedOpenAiRoutes,
  });

  final String desktopVersion;
  final File desktopExecutable;
  final String desktopApplicationId;
  final File asarFile;
  final File cliExecutable;
  final Directory canonicalCodexHome;
  final bool supportsAppServerWebSocket;
  final bool supportsManagedOpenAiRoutes;

  bool get supportsManagedProfiles =>
      supportsAppServerWebSocket && supportsManagedOpenAiRoutes;
}

class WindowsCodexInstallationDiscovery {
  WindowsCodexInstallationDiscovery({
    CodexDiscoveryPowerShellRunner? powerShellRunner,
    CodexCliResolver? cliResolver,
    Map<String, String>? environment,
  }) : _powerShellRunner = powerShellRunner ?? _runPowerShell,
       _cliResolver = cliResolver ?? _resolveCodexCli,
       _environment = environment ?? Platform.environment;

  final CodexDiscoveryPowerShellRunner _powerShellRunner;
  final CodexCliResolver _cliResolver;
  final Map<String, String> _environment;

  static const _installationScript = r'''
$package = Get-AppxPackage -Name OpenAI.Codex |
  Sort-Object Version -Descending |
  Select-Object -First 1
if ($null -eq $package -or [string]::IsNullOrWhiteSpace($package.InstallLocation)) {
  Write-Error 'OpenAI Codex AppX package was not found.'; exit 3
}
$manifest = Get-AppxPackageManifest -Package $package.PackageFullName
$application = $manifest.Package.Applications.Application | Select-Object -First 1
if ($null -eq $application -or [string]::IsNullOrWhiteSpace($application.Executable)) {
  Write-Error 'OpenAI Codex application executable was not found.'; exit 4
}
$root = [IO.Path]::GetFullPath($package.InstallLocation).TrimEnd('\')
$prefix = $root + '\'
$executable = [IO.Path]::GetFullPath((Join-Path $root ([string]$application.Executable)))
if (-not $executable.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
  Write-Error 'OpenAI Codex executable failed package-root validation.'; exit 5
}
$asar = Join-Path (Split-Path -Parent $executable) 'resources\app.asar'
[ordered]@{
  packageVersion = [string]$package.Version
  executablePath = $executable
  applicationId = [string]$application.Id
  asarPath = $asar
} | ConvertTo-Json -Compress
''';

  Future<CodexInstallation> discover() async {
    final desktop = await _discoverDesktop();
    final cli = (await _cliResolver()).absolute;
    if (!await cli.exists() ||
        path.windows.basename(cli.path).toLowerCase() != 'codex.exe') {
      throw CodexInstallationDiscoveryException(
        'Official Codex CLI executable was not found: ${cli.path}',
      );
    }
    final home = _discoverCanonicalHome();
    final supportsWebSocket = await _fileContainsAscii(
      desktop.asarFile,
      'CODEX_APP_SERVER_WS_URL',
    );
    final supportsOpenAiBase = await _fileContainsAscii(
      desktop.asarFile,
      'CODEX_APP_SERVER_OPENAI_BASE_URL',
    );
    final supportsChatGptBase = await _fileContainsAscii(
      desktop.asarFile,
      'CODEX_APP_SERVER_CHATGPT_BASE_URL',
    );
    return CodexInstallation(
      desktopVersion: desktop.version,
      desktopExecutable: desktop.executable,
      desktopApplicationId: desktop.applicationId,
      asarFile: desktop.asarFile,
      cliExecutable: cli,
      canonicalCodexHome: home,
      supportsAppServerWebSocket: supportsWebSocket,
      supportsManagedOpenAiRoutes: supportsOpenAiBase && supportsChatGptBase,
    );
  }

  Future<_DesktopInstallation> _discoverDesktop() async {
    final result = await _powerShellRunner(_installationScript);
    if (result.exitCode != 0) {
      throw CodexInstallationDiscoveryException(
        'Unable to discover the installed Codex Desktop: ${result.stderr}',
      );
    }
    try {
      final decoded = jsonDecode(result.stdout.toString().trim());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected an object.');
      }
      final version = decoded['packageVersion'];
      final executablePath = decoded['executablePath'];
      final applicationId = decoded['applicationId'];
      final asarPath = decoded['asarPath'];
      if (version is! String ||
          version.isEmpty ||
          executablePath is! String ||
          executablePath.isEmpty ||
          applicationId is! String ||
          applicationId.isEmpty ||
          asarPath is! String ||
          asarPath.isEmpty) {
        throw const FormatException('Desktop metadata is incomplete.');
      }
      final executable = File(executablePath).absolute;
      final asar = File(asarPath).absolute;
      if (!await executable.exists() || !await asar.exists()) {
        throw const FormatException('Desktop package files are missing.');
      }
      return _DesktopInstallation(
        version: version,
        executable: executable,
        applicationId: applicationId,
        asarFile: asar,
      );
    } on FormatException catch (error) {
      throw CodexInstallationDiscoveryException(
        'Installed Codex Desktop metadata is invalid: $error',
      );
    }
  }

  Directory _discoverCanonicalHome() {
    final configured = _environment['CODEX_HOME']?.trim();
    if (configured != null && configured.isNotEmpty) {
      if (!path.windows.isAbsolute(configured)) {
        throw const CodexInstallationDiscoveryException(
          'CODEX_HOME must resolve to an absolute directory.',
        );
      }
      return Directory(path.windows.normalize(configured)).absolute;
    }
    final profile = _environment['USERPROFILE']?.trim();
    if (profile == null || profile.isEmpty) {
      throw const CodexInstallationDiscoveryException(
        'Windows user profile could not be resolved for Codex discovery.',
      );
    }
    return Directory(path.windows.join(profile, '.codex')).absolute;
  }
}

class _DesktopInstallation {
  const _DesktopInstallation({
    required this.version,
    required this.executable,
    required this.applicationId,
    required this.asarFile,
  });

  final String version;
  final File executable;
  final String applicationId;
  final File asarFile;
}

Future<ProcessResult> _runPowerShell(String script) {
  return Process.run('powershell.exe', <String>[
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-WindowStyle',
    'Hidden',
    '-EncodedCommand',
    _encodePowerShell(script),
  ], runInShell: false);
}

Future<File> _resolveCodexCli() async {
  final configured = Platform.environment['CODEX_CLI_PATH']?.trim();
  if (configured != null && configured.isNotEmpty) {
    final file = File(configured).absolute;
    if (await file.exists()) {
      return file;
    }
  }
  final result = await Process.run('where.exe', const <String>[
    'codex.exe',
  ], runInShell: false);
  if (result.exitCode == 0) {
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final file = File(line.trim()).absolute;
      if (await file.exists()) {
        return file;
      }
    }
  }
  throw const CodexInstallationDiscoveryException(
    'Official Codex CLI could not be discovered.',
  );
}

Future<bool> _fileContainsAscii(File file, String needle) async {
  final pattern = ascii.encode(needle);
  var tail = <int>[];
  await for (final chunk in file.openRead()) {
    final combined = <int>[...tail, ...chunk];
    if (_indexOfBytes(combined, pattern) >= 0) {
      return true;
    }
    final keep = pattern.length - 1;
    tail = combined.length <= keep
        ? combined
        : combined.sublist(combined.length - keep);
  }
  return false;
}

int _indexOfBytes(List<int> haystack, List<int> needle) {
  final lastStart = haystack.length - needle.length;
  for (var start = 0; start <= lastStart; start += 1) {
    var matched = true;
    for (var index = 0; index < needle.length; index += 1) {
      if (haystack[start + index] != needle[index]) {
        matched = false;
        break;
      }
    }
    if (matched) {
      return start;
    }
  }
  return -1;
}

String _encodePowerShell(String script) {
  final bytes = <int>[];
  for (final unit in script.codeUnits) {
    bytes
      ..add(unit & 0xff)
      ..add((unit >> 8) & 0xff);
  }
  return base64.encode(bytes);
}
