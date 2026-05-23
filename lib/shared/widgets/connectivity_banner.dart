import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/sync_service.dart';
import '../../features/offline/presentation/pending_operations_screen.dart';

/// Banner persistente que indica o estado de conectividade do app.
///
/// Aparece em **todas** as telas autenticadas porque é renderizado no
/// `builder` do `MaterialApp.router` (em `app.dart`), envolvendo o
/// conteúdo das rotas em uma `Column`.
///
/// Comportamento:
/// - **Offline:** banner âmbar persistente — "Você está offline. Operações
///   ficarão pendentes."
/// - **Online (transição):** mostra um banner azul "Voltou online.
///   Sincronizando..." por [reconnectedFlashDuration] e depois some.
/// - **Online (estável):** sem banner.
///
/// Usa o [syncQueueStateProvider] em vez do `connectivityProvider`
/// direto porque o `SyncService` já consolida `isOnline` + `isSyncing` +
/// fila — assim o banner também segue o estado real de sincronização.
class ConnectivityBanner extends ConsumerStatefulWidget {
  /// Cria um [ConnectivityBanner].
  const ConnectivityBanner({
    super.key,
    this.reconnectedFlashDuration = const Duration(seconds: 4),
  });

  /// Quanto tempo o banner "Voltou online" permanece visível antes de
  /// sumir. Default: 4s.
  final Duration reconnectedFlashDuration;

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool? _wasOnline;
  bool _showReconnected = false;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _handleStateChange(SyncQueueState state) {
    final bool nowOnline = state.isOnline;
    if (_wasOnline == false && nowOnline) {
      // Transição offline → online: liga o flash.
      _flashTimer?.cancel();
      setState(() => _showReconnected = true);
      _flashTimer = Timer(widget.reconnectedFlashDuration, () {
        if (mounted) {
          setState(() => _showReconnected = false);
        }
      });
    } else if (_wasOnline == true && !nowOnline) {
      // Voltou offline: cancela qualquer flash residual.
      _flashTimer?.cancel();
      if (_showReconnected) {
        setState(() => _showReconnected = false);
      }
    }
    _wasOnline = nowOnline;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SyncQueueState>>(syncQueueStateProvider, (
      AsyncValue<SyncQueueState>? previous,
      AsyncValue<SyncQueueState> next,
    ) {
      final SyncQueueState? value = next.asData?.value;
      if (value != null) {
        _handleStateChange(value);
      }
    });

    final AsyncValue<SyncQueueState> async = ref.watch(syncQueueStateProvider);
    final SyncQueueState? state = async.asData?.value;

    // Enquanto o `SyncService` não resolve, esconde o banner — em
    // device real o boot é rápido e o ruído visual seria pior.
    if (state == null) {
      return const SizedBox.shrink();
    }

    if (!state.isOnline) {
      return const _BannerSurface(
        backgroundColor: Color(0xFFCA8A04),
        icon: Icons.cloud_off_outlined,
        message: 'Você está offline. Operações ficarão pendentes.',
      );
    }

    if (_showReconnected) {
      return _BannerSurface(
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icons.cloud_sync_outlined,
        message: 'Voltou online. Sincronizando...',
      );
    }

    return const SizedBox.shrink();
  }
}

class _BannerSurface extends StatelessWidget {
  const _BannerSurface({
    required this.backgroundColor,
    required this.icon,
    required this.message,
  });

  final Color backgroundColor;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
