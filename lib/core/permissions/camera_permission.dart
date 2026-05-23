import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Estado simplificado da permissão de câmera consumido pela UI.
enum CameraPermissionStatus {
  /// Ainda não foi solicitada — pode pedir sem mostrar configurações.
  notDetermined,

  /// Permissão concedida — câmera pode abrir.
  granted,

  /// Negada uma vez — ainda podemos pedir novamente.
  denied,

  /// Permanentemente negada (ou restrita) — só liberando pelas configurações.
  permanentlyDenied,
}

/// Wrapper sobre `permission_handler` para a câmera.
///
/// Existe principalmente para ser **mockável em testes** (Riverpod override) —
/// o `permission_handler` chama plugins nativos que não funcionam no ambiente
/// de teste sem device.
class CameraPermission {
  const CameraPermission();

  /// Lê o estado atual sem disparar prompt nativo.
  Future<CameraPermissionStatus> check() async {
    final status = await Permission.camera.status;
    return _map(status);
  }

  /// Solicita permissão de câmera (dispara prompt nativo se necessário).
  Future<CameraPermissionStatus> request() async {
    final status = await Permission.camera.request();
    return _map(status);
  }

  /// Abre as configurações do app para o usuário liberar permissão
  /// manualmente quando estiver `permanentlyDenied`.
  Future<bool> openSettings() => openAppSettings();

  CameraPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return CameraPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermissionStatus.permanentlyDenied;
    }
    if (status.isDenied) {
      return CameraPermissionStatus.denied;
    }
    return CameraPermissionStatus.notDetermined;
  }
}

/// Provider para injeção via Riverpod — override em testes.
final cameraPermissionProvider = Provider<CameraPermission>(
  (ref) => const CameraPermission(),
);
