import 'dart:io';

import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('RuntimeConfig', () {
    test(
      'resolves the canonical user data directory and remains attach-only without a sidecar',
      () {
        final profile = path.join(
          Directory.systemTemp.path,
          'openhub-profile',
        );
        final config = RuntimeConfig.fromEnvironment(
          arguments: const <String>[],
          environment: <String, String>{'USERPROFILE': profile},
          resolvedExecutable: path.join(profile, 'app', 'OpenHUB.exe'),
        );

        expect(config.endpoint, Uri.parse('http://127.0.0.1:2455'));
        expect(
          config.dataDirectory.path,
          path.normalize(path.join(profile, '.openhub')),
        );
        expect(
          config.backupDirectory.path,
          path.normalize(path.join(profile, '.openhub-backups')),
        );
        expect(config.attachOnly, isTrue);
        expect(config.launchCodexOnReady, isFalse);
      },
    );

    test('accepts explicit loopback configuration', () {
      final config = RuntimeConfig.fromEnvironment(
        arguments: const <String>[
          '--endpoint=http://localhost:3456',
          '--data-dir=C:\\fixtures\\openhub',
          '--backup-dir=C:\\fixtures\\backups',
          '--attach-only',
          '--launch-codex',
        ],
        environment: const <String, String>{'USERPROFILE': r'C:\Users\Tester'},
        resolvedExecutable: r'C:\app\OpenHUB.exe',
      );

      expect(config.endpoint.port, 3456);
      expect(config.attachOnly, isTrue);
      expect(config.launchCodexOnReady, isTrue);
    });

    test('accepts managed launch intent from the local environment', () {
      final config = RuntimeConfig.fromEnvironment(
        arguments: const <String>[],
        environment: const <String, String>{
          'USERPROFILE': r'C:\Users\Tester',
          'OPENHUB_NATIVE_LAUNCH_CODEX': 'true',
        },
        resolvedExecutable: r'C:\app\OpenHUB.exe',
      );

      expect(config.launchCodexOnReady, isTrue);
    });

    test('rejects non-loopback management targets', () {
      expect(
        () => RuntimeConfig.fromEnvironment(
          arguments: const <String>['--endpoint=http://192.0.2.10:2455'],
          environment: const <String, String>{
            'USERPROFILE': r'C:\Users\Tester',
          },
          resolvedExecutable: r'C:\app\OpenHUB.exe',
        ),
        throwsA(isA<RuntimeConfigException>()),
      );
    });

    test('rejects endpoint credentials and path prefixes', () {
      for (final endpoint in const <String>[
        'http://user:password@127.0.0.1:2455',
        'http://127.0.0.1:2455/admin',
        'https://127.0.0.1:2455',
      ]) {
        expect(
          () => RuntimeConfig.fromEnvironment(
            arguments: <String>['--endpoint=$endpoint'],
            environment: const <String, String>{
              'USERPROFILE': r'C:\Users\Tester',
            },
            resolvedExecutable: r'C:\app\OpenHUB.exe',
          ),
          throwsA(isA<RuntimeConfigException>()),
          reason: endpoint,
        );
      }
    });

    test('rejects unknown or empty arguments', () {
      for (final arguments in const <List<String>>[
        <String>['--unknown=value'],
        <String>['--data-dir='],
        <String>['positional'],
      ]) {
        expect(
          () => RuntimeConfig.fromEnvironment(
            arguments: arguments,
            environment: const <String, String>{
              'USERPROFILE': r'C:\Users\Tester',
            },
            resolvedExecutable: r'C:\app\OpenHUB.exe',
          ),
          throwsA(isA<RuntimeConfigException>()),
        );
      }
    });
  });
}
