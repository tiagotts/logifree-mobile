import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/permissions/camera_permission.dart';
import 'package:logifree_mobile/features/scan/application/camera_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_helpers/test_helpers.dart';

class _MockCameraPermission extends Mock implements CameraPermission {}

void main() {
  setUpAll(ensureTestBinding);

  group('ScanCameraNotifier — permissão', () {
    test('vai para ScanCameraPermissionDenied quando negada uma vez', () async {
      final permission = _MockCameraPermission();
      when(
        permission.check,
      ).thenAnswer((_) async => CameraPermissionStatus.notDetermined);
      when(
        permission.request,
      ).thenAnswer((_) async => CameraPermissionStatus.denied);

      final container = ProviderContainer(
        overrides: [
          cameraPermissionProvider.overrideWithValue(permission),
          // Não deve chegar a discovery quando a permissão é negada — passamos
          // uma função que falharia se chamada.
          cameraDiscoveryProvider.overrideWithValue(
            () async => throw StateError('discovery não deveria rodar'),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Estado inicial.
      expect(
        container.read(scanCameraControllerProvider),
        isA<ScanCameraLoading>(),
      );

      await container.read(scanCameraControllerProvider.notifier).initialize();

      final state = container.read(scanCameraControllerProvider);
      expect(state, isA<ScanCameraPermissionDenied>());
      expect((state as ScanCameraPermissionDenied).permanently, isFalse);
      verify(permission.check).called(1);
      verify(permission.request).called(1);
    });

    test(
      'vai para ScanCameraPermissionDenied(permanently: true) quando permanente',
      () async {
        final permission = _MockCameraPermission();
        when(
          permission.check,
        ).thenAnswer((_) async => CameraPermissionStatus.permanentlyDenied);
        // Não chama request — `check` já indica o status final.
        when(
          permission.request,
        ).thenAnswer((_) async => CameraPermissionStatus.permanentlyDenied);

        final container = ProviderContainer(
          overrides: [
            cameraPermissionProvider.overrideWithValue(permission),
            cameraDiscoveryProvider.overrideWithValue(
              () async => throw StateError('discovery não deveria rodar'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(scanCameraControllerProvider.notifier)
            .initialize();

        final state = container.read(scanCameraControllerProvider);
        expect(state, isA<ScanCameraPermissionDenied>());
        expect((state as ScanCameraPermissionDenied).permanently, isTrue);
      },
    );

    test('openSettings delega para CameraPermission', () async {
      final permission = _MockCameraPermission();
      when(
        permission.check,
      ).thenAnswer((_) async => CameraPermissionStatus.permanentlyDenied);
      when(permission.openSettings).thenAnswer((_) async => true);

      final container = ProviderContainer(
        overrides: [
          cameraPermissionProvider.overrideWithValue(permission),
          cameraDiscoveryProvider.overrideWithValue(() async => const []),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(scanCameraControllerProvider.notifier)
          .openSettings();

      verify(permission.openSettings).called(1);
    });
  });

  group('ScanCameraNotifier — câmera', () {
    test(
      'vai para ScanCameraError quando o device não tem nenhuma câmera',
      () async {
        final permission = _MockCameraPermission();
        when(
          permission.check,
        ).thenAnswer((_) async => CameraPermissionStatus.granted);

        final container = ProviderContainer(
          overrides: [
            cameraPermissionProvider.overrideWithValue(permission),
            cameraDiscoveryProvider.overrideWithValue(() async => const []),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(scanCameraControllerProvider.notifier)
            .initialize();

        final state = container.read(scanCameraControllerProvider);
        expect(state, isA<ScanCameraError>());
        expect((state as ScanCameraError).message, contains('Nenhuma câmera'));
      },
    );

    // NOTA: o caminho feliz (permissão concedida + câmera real iniciando) NÃO
    // tem teste unitário aqui porque exigiria mockar o `CameraController` do
    // pacote `camera` — que chama method channels nativos (`initialize`,
    // `dispose`) e não é trivial substituir sem fakear o plugin inteiro. Esse
    // caminho é coberto via teste manual em device real, conforme nota do
    // CARD-MOBILE-011.
  });
}
