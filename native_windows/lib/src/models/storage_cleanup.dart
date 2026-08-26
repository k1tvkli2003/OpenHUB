import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

enum StorageCleanupCategory {
  conversationArchives('conversation_archives', 'Conversation archives'),
  debugDumps('debug_dumps', 'Diagnostic dumps'),
  temporaryFiles('temporary_files', 'Temporary files');

  const StorageCleanupCategory(this.wireName, this.label);

  final String wireName;
  final String label;
}

class StorageCleanupCandidate {
  const StorageCleanupCandidate({
    required this.category,
    required this.relativePath,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String category;
  final String relativePath;
  final int sizeBytes;
  final DateTime modifiedAt;

  factory StorageCleanupCandidate.fromJson(Map<String, Object?> json) {
    const context = 'storageCleanup.candidates[]';
    final sizeBytes = readInt(json, 'sizeBytes', context);
    if (sizeBytes < 0) {
      throw const ApiSchemaException(
        'storageCleanup.candidates[].sizeBytes must be non-negative.',
      );
    }
    return StorageCleanupCandidate(
      category: readString(json, 'category', context),
      relativePath: readString(json, 'relativePath', context),
      sizeBytes: sizeBytes,
      modifiedAt: _requiredDateTime(json, 'modifiedAt', context),
    );
  }
}

class StorageCleanupPreview {
  const StorageCleanupPreview({
    required this.olderThanDays,
    required this.cutoff,
    required this.fileCount,
    required this.totalBytes,
    required this.confirmationToken,
    required this.candidates,
    required this.protectedRuntimeStores,
  });

  final int olderThanDays;
  final DateTime cutoff;
  final int fileCount;
  final int totalBytes;
  final String confirmationToken;
  final List<StorageCleanupCandidate> candidates;
  final bool protectedRuntimeStores;

  factory StorageCleanupPreview.fromJson(Map<String, Object?> json) {
    const context = 'storageCleanup.preview';
    final candidates = readList(json['candidates'], '$context.candidates')
        .map(
          (item) => StorageCleanupCandidate.fromJson(
            readObject(item, '$context.candidates[]'),
          ),
        )
        .toList(growable: false);
    final preview = StorageCleanupPreview(
      olderThanDays: readInt(json, 'olderThanDays', context),
      cutoff: _requiredDateTime(json, 'cutoff', context),
      fileCount: readInt(json, 'fileCount', context),
      totalBytes: readInt(json, 'totalBytes', context),
      confirmationToken: readString(json, 'confirmationToken', context),
      candidates: candidates,
      protectedRuntimeStores: readBool(json, 'protectedRuntimeStores', context),
    );
    if (preview.fileCount != candidates.length || preview.totalBytes < 0) {
      throw const ApiSchemaException(
        'storageCleanup.preview counts are inconsistent.',
      );
    }
    return preview;
  }
}

DateTime _requiredDateTime(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = readNullableDateTime(json, key, context);
  if (value == null) {
    throw ApiSchemaException('$context.$key must not be null.');
  }
  return value;
}

class StorageCleanupResult {
  const StorageCleanupResult({
    required this.deletedFiles,
    required this.deletedBytes,
    required this.skippedFiles,
    required this.protectedRuntimeStores,
  });

  final int deletedFiles;
  final int deletedBytes;
  final int skippedFiles;
  final bool protectedRuntimeStores;

  factory StorageCleanupResult.fromJson(Map<String, Object?> json) {
    const context = 'storageCleanup.apply';
    return StorageCleanupResult(
      deletedFiles: readInt(json, 'deletedFiles', context),
      deletedBytes: readInt(json, 'deletedBytes', context),
      skippedFiles: readInt(json, 'skippedFiles', context),
      protectedRuntimeStores: readBool(json, 'protectedRuntimeStores', context),
    );
  }
}
