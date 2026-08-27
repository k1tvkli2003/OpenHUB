import 'dart:convert';
import 'dart:io';

import 'windows_platform_bridge.dart';

const _managedBaseUrlEnvironment = 'CODEX_APP_SERVER_OPENAI_BASE_URL';
const _chatGptBaseUrlEnvironment = 'CODEX_APP_SERVER_CHATGPT_BASE_URL';
const _appServerWebSocketEnvironment = 'CODEX_APP_SERVER_WS_URL';

typedef CodexProcessStarter =
    Future<int> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
      String workingDirectory,
    );

class CodexDesktopCapability {
  const CodexDesktopCapability({
    required this.supported,
    required this.packageVersion,
    required this.executablePath,
    required this.applicationId,
    this.reason,
  });

  final bool supported;
  final String packageVersion;
  final String executablePath;
  final String applicationId;
  final String? reason;
}

class CodexDesktopLaunchResult {
  const CodexDesktopLaunchResult({
    required this.launched,
    required this.alreadyRunning,
    required this.managed,
    this.applicationId,
  });

  final bool launched;
  final bool alreadyRunning;
  final bool managed;
  final String? applicationId;
}

abstract interface class CodexDesktopLauncher {
  Future<bool> isRunning();

  Future<bool> focusRunning();

  Future<bool> stopRunningForRestart();

  Future<CodexDesktopCapability> inspectManagedCapability();

  Future<CodexDesktopLaunchResult> launch({
    Uri? managedBaseUrl,
    Uri? appServerWebSocketUrl,
  });
}

class WindowsCodexDesktopLauncher implements CodexDesktopLauncher {
  const WindowsCodexDesktopLauncher({
    this.powerShellRunner,
    this.processStarter,
    this.platformBridge = const WindowsPlatformBridge(),
    this.launchConfirmationTimeout = const Duration(seconds: 30),
  });

  final Future<ProcessResult> Function(String script)? powerShellRunner;
  final CodexProcessStarter? processStarter;
  final WindowsPlatformBridge platformBridge;
  final Duration launchConfirmationTimeout;

  static const _runningScript = r'''
$package = Get-AppxPackage -Name OpenAI.Codex |
  Sort-Object Version -Descending |
  Select-Object -First 1
if ($null -eq $package -or [string]::IsNullOrWhiteSpace($package.InstallLocation)) {
  Write-Output '0'
  exit 0
}
$packageRoot = [IO.Path]::GetFullPath($package.InstallLocation).TrimEnd('\')
$packagePrefix = $packageRoot + '\'
$process = Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue |
  Where-Object {
    try {
      $candidatePath = [IO.Path]::GetFullPath($_.Path)
      return $candidatePath.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)
    }
    catch {
      return $false
    }
  } |
  Select-Object -First 1
if ($null -eq $process) { Write-Output '0' } else { Write-Output '1' }
''';

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

  static const _focusScript = r'''
$package = Get-AppxPackage -Name OpenAI.Codex |
  Sort-Object Version -Descending |
  Select-Object -First 1
if ($null -eq $package -or [string]::IsNullOrWhiteSpace($package.InstallLocation)) {
  Write-Output '0'
  exit 0
}
$packageRoot = [IO.Path]::GetFullPath($package.InstallLocation).TrimEnd('\')
$packagePrefix = $packageRoot + '\'
$process = Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue |
  Where-Object {
    if ($_.MainWindowHandle -eq 0) { return $false }
    try {
      $candidatePath = [IO.Path]::GetFullPath($_.Path)
      return $candidatePath.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)
    }
    catch {
      return $false
    }
  } |
  Select-Object -First 1
if ($null -eq $process) { Write-Output '0'; exit 0 }
try {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class OpenHubWindowActivation {
  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@ -ErrorAction SilentlyContinue
  [OpenHubWindowActivation]::ShowWindowAsync($process.MainWindowHandle, 9) | Out-Null
  $shell = New-Object -ComObject WScript.Shell
  if ($shell.AppActivate($process.Id)) { Write-Output '1' } else { Write-Output '0' }
}
catch {
  Write-Output '0'
}
''';

  static const _stopForRestartScript = r'''
$package = Get-AppxPackage -Name OpenAI.Codex |
  Sort-Object Version -Descending |
  Select-Object -First 1
if ($null -eq $package -or [string]::IsNullOrWhiteSpace($package.InstallLocation)) {
  Write-Output '0'
  exit 0
}
$packageRoot = [IO.Path]::GetFullPath($package.InstallLocation).TrimEnd('\')
$packagePrefix = $packageRoot + '\'
function Get-CodexPackageProcesses {
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
      if ([string]::IsNullOrWhiteSpace($_.ExecutablePath)) { return $false }
      try {
        $candidatePath = [IO.Path]::GetFullPath($_.ExecutablePath)
        return $candidatePath.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)
      }
      catch {
        return $false
      }
    })
}
$targets = Get-CodexPackageProcesses
foreach ($target in $targets) {
  Stop-Process -Id $target.ProcessId -Force -ErrorAction SilentlyContinue
}
$deadline = [DateTime]::UtcNow.AddSeconds(10)
do {
  if ((Get-CodexPackageProcesses).Count -eq 0) {
    Write-Output '1'
    exit 0
  }
  Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)
Write-Output '0'
''';

  @override
  Future<bool> isRunning() async {
    final result = await _runPowerShell(_runningScript);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to inspect the Codex desktop process: ${result.stderr}',
      );
    }
    return result.stdout.toString().trim() == '1';
  }

  @override
  Future<bool> focusRunning() async {
    final result = await _runPowerShell(_focusScript);
    if (result.exitCode != 0) {
      return false;
    }
    return result.stdout.toString().trim() == '1';
  }

  @override
  Future<bool> stopRunningForRestart() async {
    final result = await _runPowerShell(_stopForRestartScript);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to stop the installed Codex process safely: ${result.stderr}',
      );
    }
    return result.stdout.toString().trim() == '1';
  }

  @override
  Future<CodexDesktopCapability> inspectManagedCapability() async {
    final installation = await _inspectInstallation();
    final asar = File(installation.asarPath);
    final supportsOpenAiBaseUrl = await _fileContainsAscii(
      asar,
      _managedBaseUrlEnvironment,
    );
    final supportsChatGptBaseUrl = await _fileContainsAscii(
      asar,
      _chatGptBaseUrlEnvironment,
    );
    final supportsWebSocket = await _fileContainsAscii(
      asar,
      _appServerWebSocketEnvironment,
    );
    final supported =
        supportsOpenAiBaseUrl && supportsChatGptBaseUrl && supportsWebSocket;
    return CodexDesktopCapability(
      supported: supported,
      packageVersion: installation.packageVersion,
      executablePath: installation.executablePath,
      applicationId: installation.applicationId,
      reason: supported
          ? null
          : 'This installed Codex build does not expose the managed app-server WebSocket and route overrides.',
    );
  }

  @override
  Future<CodexDesktopLaunchResult> launch({
    Uri? managedBaseUrl,
    Uri? appServerWebSocketUrl,
  }) async {
    final managed = managedBaseUrl != null || appServerWebSocketUrl != null;
    if (await isRunning()) {
      if (!managed && await focusRunning()) {
        return CodexDesktopLaunchResult(
          launched: false,
          alreadyRunning: true,
          managed: false,
        );
      }
      if (managed) {
        throw StateError(
          'Codex is still running. Fully close it before attaching a managed profile.',
        );
      }
    }
    if (managedBaseUrl != null) {
      _validateManagedBaseUrl(managedBaseUrl);
    }
    if (appServerWebSocketUrl != null) {
      _validateAppServerWebSocketUrl(appServerWebSocketUrl);
    }
    final CodexDesktopCapability capability;
    if (managed) {
      capability = await inspectManagedCapability();
      if (!capability.supported) {
        throw StateError(capability.reason ?? 'Managed launch is unsupported.');
      }
    } else {
      final installation = await _inspectInstallation();
      capability = CodexDesktopCapability(
        supported: false,
        packageVersion: installation.packageVersion,
        executablePath: installation.executablePath,
        applicationId: installation.applicationId,
      );
    }

    final environment = Map<String, String>.from(Platform.environment)
      ..remove(_managedBaseUrlEnvironment)
      ..remove(_chatGptBaseUrlEnvironment)
      ..remove(_appServerWebSocketEnvironment);
    if (managedBaseUrl != null) {
      environment[_managedBaseUrlEnvironment] = managedBaseUrl.toString();
      environment[_chatGptBaseUrlEnvironment] = _managedChatGptBaseUrl(
        managedBaseUrl,
      ).toString();
    }
    if (appServerWebSocketUrl != null) {
      environment[_appServerWebSocketEnvironment] = appServerWebSocketUrl
          .toString();
    }
    final workingDirectory = File(capability.executablePath).parent.path;
    final starter = processStarter;
    if (starter != null) {
      await starter(
        capability.executablePath,
        const <String>[],
        environment,
        workingDirectory,
      );
    } else if (managed && Platform.isWindows) {
      await platformBridge.launchManagedCodex(
        executablePath: capability.executablePath,
        workingDirectory: workingDirectory,
        chatGptBaseUrl: managedBaseUrl == null
            ? null
            : _managedChatGptBaseUrl(managedBaseUrl),
        openAiBaseUrl: managedBaseUrl,
        appServerWebSocketUrl: appServerWebSocketUrl,
      );
    } else {
      await Process.start(
        capability.executablePath,
        const <String>[],
        environment: environment,
        workingDirectory: workingDirectory,
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
    }

    final deadline = DateTime.now().add(launchConfirmationTimeout);
    var windowAppeared = false;
    while (DateTime.now().isBefore(deadline)) {
      if (await focusRunning()) {
        windowAppeared = true;
        if (!managed ||
            appServerWebSocketUrl != null ||
            await _managedRouteWasAdopted(managedBaseUrl!)) {
          return CodexDesktopLaunchResult(
            launched: true,
            alreadyRunning: false,
            managed: managed,
            applicationId: capability.applicationId,
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (windowAppeared && managed) {
      throw StateError(
        'Codex opened, but the managed runtime could not be verified. Fully quit Codex before retrying.',
      );
    }
    throw StateError(
      'The installed Codex executable started, but no Codex window appeared before the launch timeout.',
    );
  }

  Future<bool> _managedRouteWasAdopted(Uri managedBaseUrl) async {
    _validateManagedBaseUrl(managedBaseUrl);
    final openAiBaseUrl = _powerShellSingleQuoted(managedBaseUrl.toString());
    final chatGptBaseUrl = _powerShellSingleQuoted(
      _managedChatGptBaseUrl(managedBaseUrl).toString(),
    );
    final result = await _runPowerShell('''
\$package = Get-AppxPackage -Name OpenAI.Codex |
  Sort-Object Version -Descending |
  Select-Object -First 1
if (\$null -eq \$package -or [string]::IsNullOrWhiteSpace(\$package.InstallLocation)) {
  Write-Output '0'
  exit 0
}
\$packageRoot = [IO.Path]::GetFullPath(\$package.InstallLocation).TrimEnd('\\')
\$packagePrefix = \$packageRoot + '\\'
\$expectedOpenAi = '$openAiBaseUrl'
\$expectedChatGpt = '$chatGptBaseUrl'
\$process = Get-CimInstance Win32_Process |
  Where-Object {
    if (\$_.Name -ine 'codex.exe' -or [string]::IsNullOrWhiteSpace(\$_.ExecutablePath)) {
      return \$false
    }
    try {
      \$candidatePath = [IO.Path]::GetFullPath(\$_.ExecutablePath)
      if (-not \$candidatePath.StartsWith(\$packagePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return \$false
      }
      \$command = [string]\$_.CommandLine
      return \$command.Contains('app-server') -and
        \$command.Contains('chatgpt_base_url') -and
        \$command.Contains(\$expectedChatGpt) -and
        \$command.Contains('openai_base_url') -and
        \$command.Contains(\$expectedOpenAi)
    }
    catch {
      return \$false
    }
  } |
  Select-Object -First 1
if (\$null -eq \$process) { Write-Output '0' } else { Write-Output '1' }
''');
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to verify the managed Codex app-server route: ${result.stderr}',
      );
    }
    return result.stdout.toString().trim() == '1';
  }

  Future<_CodexInstallation> _inspectInstallation() async {
    final result = await _runPowerShell(_installationScript);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to locate the installed Codex app: ${result.stderr}',
      );
    }
    try {
      final decoded = jsonDecode(result.stdout.toString().trim());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected an object.');
      }
      final packageVersion = decoded['packageVersion'];
      final executablePath = decoded['executablePath'];
      final applicationId = decoded['applicationId'];
      final asarPath = decoded['asarPath'];
      if (packageVersion is! String ||
          packageVersion.isEmpty ||
          executablePath is! String ||
          executablePath.isEmpty ||
          applicationId is! String ||
          applicationId.isEmpty ||
          asarPath is! String ||
          asarPath.isEmpty) {
        throw const FormatException('Installation metadata is incomplete.');
      }
      return _CodexInstallation(
        packageVersion: packageVersion,
        executablePath: executablePath,
        applicationId: applicationId,
        asarPath: asarPath,
      );
    } on FormatException catch (error) {
      throw StateError('Installed Codex metadata is invalid: $error');
    }
  }

  Future<ProcessResult> _runPowerShell(String script) {
    final runner = powerShellRunner;
    if (runner != null) {
      return runner(script);
    }
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
}

class _CodexInstallation {
  const _CodexInstallation({
    required this.packageVersion,
    required this.executablePath,
    required this.applicationId,
    required this.asarPath,
  });

  final String packageVersion;
  final String executablePath;
  final String applicationId;
  final String asarPath;
}

Future<bool> _fileContainsAscii(File file, String needle) async {
  if (!await file.exists()) {
    return false;
  }
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
  if (needle.isEmpty) {
    return 0;
  }
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

Uri _managedChatGptBaseUrl(Uri managedOpenAiBaseUrl) {
  _validateManagedBaseUrl(managedOpenAiBaseUrl);
  return managedOpenAiBaseUrl.replace(path: '/backend-api/codex-managed');
}

void _validateManagedBaseUrl(Uri uri) {
  final address = InternetAddress.tryParse(uri.host);
  if (uri.scheme != 'http' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      address == null ||
      !address.isLoopback ||
      uri.path != '/backend-api/codex-managed/v1') {
    throw ArgumentError.value(
      uri,
      'managedBaseUrl',
      'Managed Codex launch requires the fixed numeric loopback URL.',
    );
  }
}

void _validateAppServerWebSocketUrl(Uri uri) {
  final address = InternetAddress.tryParse(uri.host);
  if (uri.scheme != 'ws' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      address == null ||
      !address.isLoopback ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError.value(
      uri,
      'appServerWebSocketUrl',
      'Managed Codex launch requires numeric loopback WebSocket.',
    );
  }
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

String _powerShellSingleQuoted(String value) => value.replaceAll("'", "''");
