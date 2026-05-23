import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/storage/secure_storage.dart';
import 'package:logifree_mobile/core/storage/secure_storage_keys.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('SecureStorage', () {
    late _MockFlutterSecureStorage mockStorage;
    late SecureStorage storage;

    setUp(() {
      mockStorage = _MockFlutterSecureStorage();
      storage = SecureStorage(storage: mockStorage);
    });

    test('read delega para FlutterSecureStorage e devolve o valor', () async {
      when(
        () => mockStorage.read(key: SecureStorageKeys.accessToken),
      ).thenAnswer((_) async => 'jwt-token');

      final result = await storage.read(SecureStorageKeys.accessToken);

      expect(result, 'jwt-token');
      verify(
        () => mockStorage.read(key: SecureStorageKeys.accessToken),
      ).called(1);
    });

    test('read devolve null quando a chave não existe', () async {
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);

      final result = await storage.read(SecureStorageKeys.refreshToken);

      expect(result, isNull);
    });

    test('write delega para FlutterSecureStorage com key e value', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await storage.write(
        SecureStorageKeys.selectedCondominiumSlug,
        'condo-xpto',
      );

      verify(
        () => mockStorage.write(
          key: SecureStorageKeys.selectedCondominiumSlug,
          value: 'condo-xpto',
        ),
      ).called(1);
    });

    test('delete delega para FlutterSecureStorage com a key correta', () async {
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await storage.delete(SecureStorageKeys.userId);

      verify(() => mockStorage.delete(key: SecureStorageKeys.userId)).called(1);
    });

    test('deleteAll delega para FlutterSecureStorage', () async {
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

      await storage.deleteAll();

      verify(() => mockStorage.deleteAll()).called(1);
    });

    test('usa instância padrão quando nenhum storage é injetado', () {
      // Smoke test: instanciar sem injeção não pode lançar.
      // (Não exercitamos métodos aqui porque o plugin nativo não roda em test env.)
      expect(SecureStorage.new, returnsNormally);
    });
  });
}
