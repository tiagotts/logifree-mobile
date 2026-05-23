import 'dart:async';
import 'dart:developer' as developer;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/camera_permission.dart';

/// Estados possíveis do `CameraController`.
sealed class ScanCameraState {
  const ScanCameraState();
}

/// Carregando: pedindo permissão e/ou inicializando o `CameraController`.
class ScanCameraLoading extends ScanCameraState {
  const ScanCameraLoading();
}

/// Pronto: a câmera está aberta e o preview pode ser mostrado.
class ScanCameraReady extends ScanCameraState {
  const ScanCameraReady(this.controller);

  /// `CameraController` do pacote `camera`, já inicializado.
  final CameraController controller;
}

/// Permissão de câmera negada — UI mostra empty state com "Abrir configurações".
class ScanCameraPermissionDenied extends ScanCameraState {
  const ScanCameraPermissionDenied({this.permanently = false});

  /// `true` quando o sistema marcou como permanentemente negada — só liberando
  /// nas configurações do app.
  final bool permanently;
}

/// Falha técnica ao inicializar a câmera (sem câmera, plugin indisponível, etc.).
class ScanCameraError extends ScanCameraState {
  const ScanCameraError(this.message);
  final String message;
}

/// Função que descobre câmeras disponíveis no device.
///
/// Existe como typedef para permitir override em testes — `availableCameras()`
/// do pacote `camera` chama um method channel nativo e não funciona em test
/// environment sem device.
typedef CameraDiscovery = Future<List<CameraDescription>> Function();

/// Factory de `CameraController` — também injetável para testes.
typedef CameraControllerFactory =
    CameraController Function(CameraDescription description);

/// `Notifier` que controla o ciclo de vida do `CameraController` do scan.
///
/// Estados expostos: [ScanCameraLoading], [ScanCameraReady],
/// [ScanCameraPermissionDenied], [ScanCameraError].
class ScanCameraNotifier extends Notifier<ScanCameraState> {
  CameraController? _controller;
  bool _disposed = false;

  @override
  ScanCameraState build() {
    ref.onDispose(_disposeController);
    // Estado inicial: ainda não foi pedida permissão / não inicializou.
    return const ScanCameraLoading();
  }

  /// Pede permissão (se necessário) e inicializa o `CameraController`.
  ///
  /// Idempotente: se já estiver `ScanCameraReady`, não reinicializa.
  Future<void> initialize() async {
    if (state is ScanCameraReady) return;
    if (_disposed) return;
    state = const ScanCameraLoading();

    final permission = ref.read(cameraPermissionProvider);
    final current = await permission.check();
    final status = current == CameraPermissionStatus.granted
        ? current
        : await permission.request();

    if (_disposed) return;

    switch (status) {
      case CameraPermissionStatus.granted:
        await _bootCamera();
      case CameraPermissionStatus.permanentlyDenied:
        state = const ScanCameraPermissionDenied(permanently: true);
      case CameraPermissionStatus.denied:
      case CameraPermissionStatus.notDetermined:
        state = const ScanCameraPermissionDenied();
    }
  }

  /// Abre as configurações do sistema para o usuário liberar permissão.
  Future<void> openSettings() async {
    final permission = ref.read(cameraPermissionProvider);
    await permission.openSettings();
  }

  Future<void> _bootCamera() async {
    try {
      final discover = ref.read(cameraDiscoveryProvider);
      final cameras = await discover();
      if (_disposed) return;

      if (cameras.isEmpty) {
        state = const ScanCameraError('Nenhuma câmera disponível no aparelho.');
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final factory = ref.read(cameraControllerFactoryProvider);
      final controller = factory(back);
      _controller = controller;
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      state = ScanCameraReady(controller);
    } on CameraException catch (e, st) {
      developer.log(
        'Falha ao inicializar câmera',
        name: 'ScanCameraNotifier',
        error: e,
        stackTrace: st,
      );
      state = ScanCameraError(e.description ?? 'Erro ao abrir a câmera.');
    } on Object catch (e, st) {
      developer.log(
        'Erro inesperado ao inicializar câmera',
        name: 'ScanCameraNotifier',
        error: e,
        stackTrace: st,
      );
      state = const ScanCameraError('Erro ao abrir a câmera.');
    }
  }

  Future<void> _disposeController() async {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } on Object catch (e, st) {
        developer.log(
          'Erro ao liberar CameraController',
          name: 'ScanCameraNotifier',
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}

/// Provider raiz do controller da câmera do scan.
final scanCameraControllerProvider =
    NotifierProvider<ScanCameraNotifier, ScanCameraState>(
      ScanCameraNotifier.new,
    );

/// Override-friendly: lista as câmeras do device.
final cameraDiscoveryProvider = Provider<CameraDiscovery>(
  (ref) => availableCameras,
);

/// Override-friendly: cria o `CameraController` propriamente dito.
final cameraControllerFactoryProvider = Provider<CameraControllerFactory>(
  (ref) => _defaultControllerFactory,
);

CameraController _defaultControllerFactory(CameraDescription description) {
  return CameraController(
    description,
    ResolutionPreset.high,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.yuv420,
  );
}
