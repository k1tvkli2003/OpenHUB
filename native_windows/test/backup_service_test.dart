import 'dart:io';

import 'package:openhub_windows/src/core/runtime/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'openhub-native-backup-test-',
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test(
    'copies the database-key pair and verifies the copied database',
    () async {
      final data = Directory(path.join(sandbox.path, 'data'));
      final backups = Directory(path.join(sandbox.path, 'backups'));
      await data.create();
      await File(
        path.join(data.path, 'store.db'),
      ).writeAsBytes(<int>[1, 2, 3, 4]);
      await File(
        path.join(data.path, 'encryption.key'),
      ).writeAsString('fixture-key');
      await File(
        path.join(data.path, 'store.db-wal'),
      ).writeAsBytes(<int>[5, 6]);
      await File(
        path.join(data.path, 'store.db-shm'),
      ).writeAsBytes(const <int>[]);
      await File(
        path.join(data.path, 'store.db.migrate-lock'),
      ).writeAsBytes(const <int>[]);

      File? probed;
      final hardened = <String>[];
      final service = BackupService((database) async {
        probed = database;
        expect(await database.readAsBytes(), <int>[1, 2, 3, 4]);
      }, hardenPrivatePath: (target) async => hardened.add(target));

      final result = await service.createVerifiedBackup(
        dataDirectory: data,
        backupRoot: backups,
      );

      expect(result.wasRequired, isTrue);
      expect(result.directory, isNotNull);
      expect(hardened, <String>[
        result.directory!.path,
        result.directory!.path,
      ]);
      expect(probed?.path, path.join(result.directory!.path, 'store.db'));
      expect(
        result.files,
        containsAll(<String>[
          'store.db',
          'encryption.key',
          'store.db-wal',
          'store.db.migrate-lock',
        ]),
      );
      expect(result.files, isNot(contains('store.db-shm')));
      expect(
        await File(
          path.join(result.directory!.path, 'encryption.key'),
        ).readAsString(),
        'fixture-key',
      );
    },
  );

  test('does nothing for a genuinely new empty data directory', () async {
    final data = Directory(path.join(sandbox.path, 'new-data'));
    final backups = Directory(path.join(sandbox.path, 'backups'));
    await data.create();
    var probed = false;
    final result = await BackupService(
      (_) async => probed = true,
    ).createVerifiedBackup(dataDirectory: data, backupRoot: backups);

    expect(result.wasRequired, isFalse);
    expect(result.directory, isNull);
    expect(probed, isFalse);
  });

  test('blocks an incomplete live pair', () async {
    final data = Directory(path.join(sandbox.path, 'broken-data'));
    await data.create();
    await File(path.join(data.path, 'store.db')).writeAsBytes(<int>[1]);

    expect(
      () => BackupService((_) async {}).createVerifiedBackup(
        dataDirectory: data,
        backupRoot: Directory(path.join(sandbox.path, 'backups')),
      ),
      throwsA(isA<BackupException>()),
    );
  });

  test('blocks nested backup roots', () async {
    final data = Directory(path.join(sandbox.path, 'data'));
    await data.create();

    expect(
      () => BackupService((_) async {}).createVerifiedBackup(
        dataDirectory: data,
        backupRoot: Directory(path.join(data.path, 'backups')),
      ),
      throwsA(isA<BackupException>()),
    );
  });

  test(
    'retains the failed copy path when integrity verification fails',
    () async {
      final data = Directory(path.join(sandbox.path, 'data'));
      await data.create();
      await File(path.join(data.path, 'store.db')).writeAsBytes(<int>[1, 2, 3]);
      await File(
        path.join(data.path, 'encryption.key'),
      ).writeAsString('fixture-key');

      try {
        await BackupService(
          (_) async => throw const BackupException('integrity failed'),
        ).createVerifiedBackup(
          dataDirectory: data,
          backupRoot: Directory(path.join(sandbox.path, 'backups')),
        );
        fail('Expected preservation gate to fail.');
      } on BackupException catch (error) {
        expect(error.message, 'integrity failed');
      }
    },
  );

  test('blocks preservation when private ACL hardening fails', () async {
    final data = Directory(path.join(sandbox.path, 'data'));
    await data.create();
    await File(path.join(data.path, 'store.db')).writeAsBytes(<int>[1, 2, 3]);
    await File(
      path.join(data.path, 'encryption.key'),
    ).writeAsString('fixture-key');

    await expectLater(
      BackupService(
        (_) async {},
        hardenPrivatePath: (_) async => throw StateError('ACL rejected'),
      ).createVerifiedBackup(
        dataDirectory: data,
        backupRoot: Directory(path.join(sandbox.path, 'backups')),
      ),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('Unable to create a verified pre-start backup'),
        ),
      ),
    );
  });
}
