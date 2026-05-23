import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../application/camera_controller.dart';
import '../application/ocr_controller.dart';

/// Captura ao vivo da etiqueta da encomenda.
///
/// Fluxo principal:
/// 1. Pede permissão de câmera (via `ScanCameraNotifier`).
/// 2. Mostra `CameraPreview` fullscreen com overlay de mira.
/// 3. Loop de detecção: a cada ~600ms tira uma foto, roda OCR + barcode scan.
///    Quando detecta barcode, dispara haptic + navega para `/scan/confirm`.
/// 4. Botões de fallback: "Capturar manualmente", "Galeria" e "Cancelar".
///
/// Por que polling com `takePicture` em vez de `startImageStream`?
/// `startImageStream` exige conversão `CameraImage` → `InputImage` específica
/// por plataforma (YUV420 no Android, BGRA8888 no iOS) e é frágil quanto a
/// orientação. Para o MVP, o polling de ~1-2 fps já é suficiente: o porteiro
/// só precisa de ~1s de latência da etiqueta ser reconhecida.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final ImagePicker _picker = ImagePicker();

  Timer? _detectionTimer;
  bool _isCapturing = false;
  bool _hasNavigated = false;
  bool _initialized = false;

  /// Intervalo entre detecções automáticas. ~1.6 fps — equilibra responsividade
  /// e custo de CPU/bateria (OCR + barcode scanning são caros).
  static const Duration _detectionInterval = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    // Inicialização da câmera precisa rodar fora do `initState` para poder
    // mexer no estado do `Notifier`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialized || !mounted) return;
      _initialized = true;
      ref.read(scanCameraControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    super.dispose();
  }

  void _ensureDetectionLoop(CameraController controller) {
    if (_detectionTimer != null) return;
    _detectionTimer = Timer.periodic(_detectionInterval, (_) {
      _tryAutoCapture(controller);
    });
  }

  Future<void> _tryAutoCapture(CameraController controller) async {
    if (_isCapturing || _hasNavigated) return;
    if (!controller.value.isInitialized) return;

    _isCapturing = true;
    try {
      final service = ref.read(scanCaptureServiceProvider);
      final capture = await service.captureFromCamera(controller);
      if (capture == null) return;
      if (!mounted || _hasNavigated) return;

      // Só navega automaticamente se OCR achou um barcode — caso contrário
      // descarta este frame e segue esperando.
      if (capture.ocr.hasBarcodes) {
        await HapticFeedback.mediumImpact();
        _hasNavigated = true;
        _detectionTimer?.cancel();
        if (!mounted) return;
        await context.push('/scan/confirm', extra: capture);
      } else {
        // Apaga a foto efêmera — só guardamos a que vai pra confirmação.
        unawaited(_silentlyDelete(capture.photoPath));
      }
    } on Object catch (e, st) {
      developer.log(
        'Erro no loop de auto-captura',
        name: 'ScanScreen',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _captureManually(CameraController controller) async {
    if (_isCapturing || _hasNavigated) return;
    _detectionTimer?.cancel();
    _isCapturing = true;
    try {
      final service = ref.read(scanCaptureServiceProvider);
      final capture = await service.captureFromCamera(controller);
      if (capture == null || !mounted) return;
      _hasNavigated = true;
      await HapticFeedback.lightImpact();
      if (!mounted) return;
      await context.push('/scan/confirm', extra: capture);
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isCapturing || _hasNavigated) return;
    _detectionTimer?.cancel();
    _isCapturing = true;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) {
        // Usuário cancelou — retoma o loop se a câmera ainda está ativa.
        final state = ref.read(scanCameraControllerProvider);
        if (state is ScanCameraReady) {
          _ensureDetectionLoop(state.controller);
        }
        return;
      }
      final service = ref.read(scanCaptureServiceProvider);
      final capture = await service.captureFromFile(picked.path);
      if (!mounted) return;
      _hasNavigated = true;
      await context.push('/scan/confirm', extra: capture);
    } on Object catch (e, st) {
      developer.log(
        'Erro ao selecionar imagem da galeria',
        name: 'ScanScreen',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _silentlyDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Arquivo temporário — ignorar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanCameraControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Cancelar',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            tooltip: 'Selecionar da galeria',
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: switch (state) {
        ScanCameraLoading() => const _LoadingView(),
        ScanCameraReady(:final controller) => _ReadyView(
          controller: controller,
          onManualCapture: () => _captureManually(controller),
          onMount: () => _ensureDetectionLoop(controller),
        ),
        ScanCameraPermissionDenied(:final permanently) => _PermissionDeniedView(
          permanently: permanently,
          onOpenSettings: () =>
              ref.read(scanCameraControllerProvider.notifier).openSettings(),
          onRetry: () =>
              ref.read(scanCameraControllerProvider.notifier).initialize(),
          onGallery: _pickFromGallery,
        ),
        ScanCameraError(:final message) => _ErrorView(
          message: message,
          onRetry: () =>
              ref.read(scanCameraControllerProvider.notifier).initialize(),
          onGallery: _pickFromGallery,
        ),
      },
    );
  }
}

/// View padrão enquanto a câmera é inicializada / a permissão é checada.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Abrindo a câmera...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Preview fullscreen + overlay de mira + botão "Capturar manualmente".
class _ReadyView extends StatefulWidget {
  const _ReadyView({
    required this.controller,
    required this.onManualCapture,
    required this.onMount,
  });

  final CameraController controller;
  final VoidCallback onManualCapture;
  final VoidCallback onMount;

  @override
  State<_ReadyView> createState() => _ReadyViewState();
}

class _ReadyViewState extends State<_ReadyView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMount());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 1 / widget.controller.value.aspectRatio,
            child: CameraPreview(widget.controller),
          ),
        ),
        const _AimOverlay(),
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aponte para a etiqueta — capturamos automaticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onManualCapture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capturar manualmente'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Overlay com área retangular destacando a região da etiqueta.
class _AimOverlay extends StatelessWidget {
  const _AimOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * 0.8;
          final height = constraints.maxHeight * 0.35;
          return Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Empty state mostrado quando a permissão de câmera está negada.
class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanently,
    required this.onOpenSettings,
    required this.onRetry,
    required this.onGallery,
  });

  final bool permanently;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final message = permanently
        ? 'Permissão de câmera bloqueada. Libere nas configurações para '
              'escanear etiquetas.'
        : 'Precisamos da câmera para ler a etiqueta. Toque em "Permitir" '
              'para continuar.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            const Text(
              'Câmera indisponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (permanently)
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Abrir configurações'),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Usar foto da galeria'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// View de erro técnico (sem câmera no aparelho, plugin indisponível, etc.).
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onGallery,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Usar foto da galeria'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
