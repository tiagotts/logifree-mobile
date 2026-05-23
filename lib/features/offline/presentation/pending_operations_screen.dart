import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/pending_operation.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/storage/offline_queue.dart';
import '../../../core/utils/formatters.dart';
import 'pending_operation_label.dart';

/// Stream consolidado do estado da fila offline.
///
/// Funde o snapshot inicial síncrono ([SyncService.currentState]) com o
/// [SyncService.stateStream] usando um [StreamProvider] simples. A UI
/// consome via `ref.watch(syncQueueStateProvider)` e reage tanto a
/// mudanças de conectividade quanto a mutações da fila.
final StreamProvider<SyncQueueState> syncQueueStateProvider =
    StreamProvider<SyncQueueState>((Ref ref) async* {
      final SyncService service = await ref.watch(syncServiceProvider.future);
      // Emite o estado atual imediatamente — o stream do service é
      // broadcast e só dispara em mudanças, então sem este `yield`
      // a UI pode ficar em loading para sempre se nada mudar.
      yield service.currentState;
      yield* service.stateStream;
    });

/// Tela de operações pendentes (CARD-022 — tela 3.1).
///
/// Lista as operações que estão na fila offline, com ações para retentar
/// ou descartar individualmente. Atualiza ao vivo via o stream do
/// [SyncService].
class PendingOperationsScreen extends ConsumerWidget {
  /// Cria uma [PendingOperationsScreen].
  const PendingOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SyncQueueState> state = ref.watch(syncQueueStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Operações pendentes')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => _ErrorState(message: '$err'),
        data: (SyncQueueState s) => _PendingList(state: s),
      ),
    );
  }
}

class _PendingList extends ConsumerWidget {
  const _PendingList({required this.state});

  final SyncQueueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PendingOperation> ops = state.operations;

    return RefreshIndicator(
      onRefresh: () async {
        final SyncService service = await ref.read(syncServiceProvider.future);
        await service.drainNow();
      },
      child: ops.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: ops.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final PendingOperation op = ops[index];
                return _PendingOperationCard(
                  operation: op,
                  onRetry: () => _onRetry(context, ref, op),
                  onDiscard: () => _onDiscard(context, ref, op),
                );
              },
            ),
    );
  }

  Future<void> _onRetry(
    BuildContext context,
    WidgetRef ref,
    PendingOperation op,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SyncService service = await ref.read(syncServiceProvider.future);
    await service.retry(op.id);
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Nova tentativa agendada.')),
    );
  }

  Future<void> _onDiscard(
    BuildContext context,
    WidgetRef ref,
    PendingOperation op,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Descartar operação?'),
          content: const Text(
            'A operação será removida da fila e não será mais '
            'sincronizada com o servidor. Essa ação não pode ser '
            'desfeita.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Descartar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final OfflineQueue queue = await ref.read(offlineQueueProvider.future);
    await queue.delete(op.id);
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Operação descartada.')),
    );
  }
}

class _PendingOperationCard extends StatelessWidget {
  const _PendingOperationCard({
    required this.operation,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingOperation operation;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = describePendingOperation(operation);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: operation.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatFullDateTime(operation.createdAt.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tentativas: ${operation.attempts}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (operation.lastError != null &&
                operation.lastError!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Último erro: ${operation.lastError}',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Descartar'),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PendingOperationStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ({Color color, String label}) data = switch (status) {
      PendingOperationStatus.pending => (
        color: const Color(0xFFCA8A04), // âmbar
        label: 'Pendente',
      ),
      PendingOperationStatus.sending => (
        color: colors.primary,
        label: 'Enviando',
      ),
      PendingOperationStatus.failed => (color: colors.error, label: 'Falhou'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          color: data.color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      children: <Widget>[
        Icon(
          Icons.cloud_done_outlined,
          size: 64,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'Tudo sincronizado.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Nenhuma operação pendente.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: colors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar a fila offline.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
