import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

typedef SqliteIntegrityProbe = Future<void> Function(File database);
typedef PrivatePathHardener = Future<void> Function(String path);

class BackupException implements Exception {
  const BackupException(this.message, {this.backupPath});

  final String message;
  final String? backupPath;

  @override
  String toString() => message;
}

class BackupResult {
  const BackupResult({
    required this.directory,
    required this.files,
    required this.wasRequired,
  });

  final Directory? directory;
  final List<String> files;
  final bool wasRequired;
}

class BackupService {
  const BackupService(this._integrityProbe, {this.hardenPrivatePath});

  final SqliteIntegrityProbe _integrityProbe;
  final PrivatePathHardener? hardenPrivatePath;

  Future<BackupResult> createVerifiedBackup({
    required Directory dataDirectory,
    required Directory backupRoot,
  }) async {
    final dataPath = path.normalize(path.absolute(dataDirectory.path));
    final backupPath = path.normalize(path.absolute(backupRoot.path));
    if (path.equals(dataPath, backupPath) ||
        path.isWithin(dataPath, backupPath) ||
        path.isWithin(backupPath, dataPath)) {
      throw const BackupException(
        'The backup directory must be separate from the live data directory.',
      );
    }

    final database = File(path.join(dataPath, 'store.db'));
    final key = File(path.join(dataPath, 'encryption.key'));
    if (!await database.exists() && !await key.exists()) {
      return const BackupResult(
        directory: null,
        files: <String>[],
        wasRequired: false,
      );
    }
    if (!await database.exists() || !await key.exists()) {
      throw const BackupException(
        'The existing data directory is incomplete; store.db and encryption.key must be preserved together.',
      );
    }

    await backupRoot.create(recursive: true);
    final destination = await _createUniqueDestination(backupRoot);
    final copied = <String>[];
    try {
      await hardenPrivatePath?.call(destination.path);
      for (final name in const <String>[
        'store.db',
        'encryption.key',
        'store.db-wal',
        'store.db-shm',
        'store.db.migrate-lock',
      ]) {
        final source = File(path.join(dataPath, name));
        if (!await source.exists()) {
          continue;
        }
        if ((name == 'store.db-wal' || name == 'store.db-shm') &&
            await source.length() == 0) {
          continue;
        }
        final target = File(path.join(destination.path, name));
        await source.copy(target.path);
        if (!await _hashesMatch(source, target)) {
          throw BackupException(
            'Backup verification failed while copying $name.',
            backupPath: destination.path,
          );
        }
        copied.add(name);
      }

      final databaseCopy = File(path.join(destination.path, 'store.db'));
      await _integrityProbe(databaseCopy);
      await hardenPrivatePath?.call(destination.path);
      return BackupResult(
        directory: destination,
        files: List.unmodifiable(copied),
        wasRequired: true,
      );
    } on BackupException {
      rethrow;
    } on Object catch (error) {
      throw BackupException(
        'Unable to create a verified pre-start backup: $error',
        backupPath: destination.path,
      );
    }
  }

  Future<Directory> _createUniqueDestination(Directory root) async {
    final now = DateTime.now().toUtc();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}-native-prestart';
    for (var suffix = 0; suffix < 100; suffix += 1) {
      final name = suffix == 0 ? stamp : '$stamp-$suffix';
      final candidate = Directory(path.join(root.path, name));
      if (!await candidate.exists()) {
        return candidate.create();
      }
    }
    throw const BackupException(
      'Unable to allocate a unique backup directory.',
    );
  }

  Future<bool> _hashesMatch(File source, File target) async {
    final sourceHash = await sha256.bind(source.openRead()).first;
    final targetHash = await sha256.bind(target.openRead()).first;
    return sourceHash == targetHash;
  }
}
