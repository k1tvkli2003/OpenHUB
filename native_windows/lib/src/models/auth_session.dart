import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class AuthSession {
  const AuthSession({
    required this.authenticated,
    required this.passwordRequired,
    required this.totpRequiredOnLogin,
    required this.totpConfigured,
    required this.bootstrapRequired,
    required this.bootstrapTokenConfigured,
    required this.authMode,
    required this.passwordManagementEnabled,
    required this.passwordSessionActive,
    required this.role,
    required this.permissions,
    required this.guestAccessEnabled,
    required this.guestPasswordRequired,
  });

  final bool authenticated;
  final bool passwordRequired;
  final bool totpRequiredOnLogin;
  final bool totpConfigured;
  final bool bootstrapRequired;
  final bool bootstrapTokenConfigured;
  final String authMode;
  final bool passwordManagementEnabled;
  final bool passwordSessionActive;
  final String role;
  final Set<String> permissions;
  final bool guestAccessEnabled;
  final bool guestPasswordRequired;

  bool get canRead => permissions.contains('read');
  bool get canWrite => permissions.contains('write');

  factory AuthSession.fromJson(Map<String, Object?> json) {
    final permissions = readList(json['permissions'], 'auth.permissions').map((
      item,
    ) {
      if (item is! String) {
        throw const ApiSchemaException(
          'auth.permissions entries must be strings.',
        );
      }
      return item;
    }).toSet();
    return AuthSession(
      authenticated: readBool(json, 'authenticated', 'auth'),
      passwordRequired: readBool(json, 'passwordRequired', 'auth'),
      totpRequiredOnLogin: readBool(json, 'totpRequiredOnLogin', 'auth'),
      totpConfigured: readBool(json, 'totpConfigured', 'auth', fallback: false),
      bootstrapRequired: readBool(
        json,
        'bootstrapRequired',
        'auth',
        fallback: false,
      ),
      bootstrapTokenConfigured: readBool(
        json,
        'bootstrapTokenConfigured',
        'auth',
        fallback: false,
      ),
      authMode: readString(json, 'authMode', 'auth'),
      passwordManagementEnabled: readBool(
        json,
        'passwordManagementEnabled',
        'auth',
        fallback: true,
      ),
      passwordSessionActive: readBool(
        json,
        'passwordSessionActive',
        'auth',
        fallback: false,
      ),
      role: readString(json, 'role', 'auth'),
      permissions: Set.unmodifiable(permissions),
      guestAccessEnabled: readBool(
        json,
        'guestAccessEnabled',
        'auth',
        fallback: false,
      ),
      guestPasswordRequired: readBool(
        json,
        'guestPasswordRequired',
        'auth',
        fallback: false,
      ),
    );
  }
}
