import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/sync_service.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/session_providers.dart';
import '../../offline/presentation/pending_operations_screen.dart';
import '../application/packages_providers.dart';
import '../domain/daily_summary.dart';
import '../domain/package_status.dart';
import 'widgets/package_card.dart';

/// Painel inicial do porteiro: resumo do dia, ação de escanear e últimos
/// pacotes registrados.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(dailySummaryProvider);
    final recent = ref.watch(recentPackagesProvider);
    final AsyncValue<SyncQueueState> queueState = ref.watch(
      syncQueueStateProvider,
    );
    final int pendingCount = queueState.asData?.value.operations.length ?? 0;
    final doorman = ref.watch(currentDoormanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(doorman.condominium),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Perfil',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Olá, ${doorman.firstName}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatWeekday(DateTime.now()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _SummaryRow(summary: summary),
          const SizedBox(height: 20),
          _ScanButton(onTap: () => context.push('/scan')),
          if (pendingCount > 0) ...[
            const SizedBox(height: 12),
            _PendingOpsBadge(
              count: pendingCount,
              onTap: () => context.push('/pending'),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'Últimos pacotes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/packages'),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final package in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PackageCard(
                package: package,
                onTap: () => context.push('/packages/${package.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            value: summary.receivedToday,
            label: 'Recebidos hoje',
            icon: Icons.inventory_2_outlined,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            value: summary.awaitingPickup,
            label: 'Aguardando retirada',
            icon: Icons.schedule_outlined,
            color: PackageStatus.awaitingPickup.color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            value: summary.deliveredToday,
            label: 'Entregues hoje',
            icon: Icons.check_circle_outline,
            color: PackageStatus.delivered.color,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOpsBadge extends StatelessWidget {
  const _PendingOpsBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // Tom âmbar discreto — combina com o banner offline e não compete
    // com a ação primária "Escanear pacote".
    const Color amber = Color(0xFFCA8A04);
    final String label = count == 1
        ? '1 operação pendente'
        : '$count operações pendentes';

    return Material(
      color: amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined, color: amber, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        color: amber,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aguardando sincronização com o servidor.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: amber),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  color: colors.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escanear Pacote',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registrar uma nova encomenda',
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: colors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
