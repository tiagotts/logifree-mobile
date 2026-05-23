import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper testável em torno de [FlutterSecureStorage].
///
/// Toda persistência de dados sensíveis (tokens, slug de tenant, userId)
/// passa por aqui. O `FlutterSecureStorage` é injetável para permitir
/// mock direto em testes com `mocktail`.
///
/// Plataformas:
/// - Android: usa o storage criptografado padrão do plugin (a antiga
///   flag `encryptedSharedPreferences` foi descontinuada no v10 — a
///   migração para custom ciphers é automática).
/// - iOS: acessibilidade após primeiro unlock (token sobrevive a reboot,
///   mas só fica acessível após o usuário desbloquear o device pela
///   primeira vez).
///
/// Uso típico via Riverpod:
/// ```dart
/// final storage = ref.read(secureStorageProvider);
/// await storage.write(SecureStorageKeys.accessToken, jwt);
/// ```
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions.defaultOptions,
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  /// Lê o valor associado a [key]; retorna `null` se inexistente.
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  /// Persiste [value] sob [key], sobrescrevendo valor anterior.
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  /// Remove a entrada [key] (no-op se não existir).
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  /// Remove todas as entradas do storage. Útil em logout.
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}

/// Provider singleton do [SecureStorage].
///
/// Manual (sem codegen) porque o projeto ainda não usa
/// `riverpod_generator` — ver decisão no backlog.
final Provider<SecureStorage> secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(),
);
