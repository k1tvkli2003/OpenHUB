import 'api_exception.dart';

Map<String, Object?> readObject(Object? value, String context) {
  if (value is! Map) {
    throw ApiSchemaException('$context must be a JSON object.');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Object?> readList(Object? value, String context) {
  if (value is! List) {
    throw ApiSchemaException('$context must be a JSON array.');
  }
  return value.cast<Object?>();
}

String readString(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value is! String) {
    throw ApiSchemaException('$context.$key must be a string.');
  }
  return value;
}

String? readNullableString(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiSchemaException('$context.$key must be a string or null.');
  }
  return value;
}

num readNumber(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value is! num) {
    throw ApiSchemaException('$context.$key must be a number.');
  }
  return value;
}

num? readNullableNumber(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw ApiSchemaException('$context.$key must be a number or null.');
  }
  return value;
}

int readInt(Map<String, Object?> json, String key, String context) {
  final value = readNumber(json, key, context);
  if (value != value.roundToDouble()) {
    throw ApiSchemaException('$context.$key must be an integer.');
  }
  return value.toInt();
}

bool readBool(
  Map<String, Object?> json,
  String key,
  String context, {
  bool? fallback,
}) {
  final value = json[key];
  if (value == null && fallback != null) {
    return fallback;
  }
  if (value is! bool) {
    throw ApiSchemaException('$context.$key must be a boolean.');
  }
  return value;
}

DateTime? readNullableDateTime(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiSchemaException('$context.$key must be an ISO-8601 date or null.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ApiSchemaException('$context.$key is not a valid ISO-8601 date.');
  }
  return parsed.toUtc();
}

Map<String, Object?>? readNullableObject(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = json[key];
  return value == null ? null : readObject(value, '$context.$key');
}
