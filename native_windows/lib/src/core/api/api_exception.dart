class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String code;
  final int? statusCode;
  final Object? details;

  bool get isNetworkFailure => statusCode == null;

  @override
  String toString() => message;
}

class ApiSchemaException extends ApiException {
  const ApiSchemaException(String message, {super.details})
    : super(message: message, code: 'invalid_response_schema');
}
