import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../application/packages_providers.dart';
import '../domain/package.dart';
import '../domain/package_event.dart';
import '../domain/package_status.dart';
import 'widgets/status_chip.dart';

/// Detalhes completos de um pacote, com histórico e ações contextuais.
class PackageDetailsScreen extends ConsumerWidget {
  const PackageDetailsScreen({super.key, required this.packageId});

  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(packageByIdProvider(packageId));

    if (package == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes do pacote')),
        body: const Center(child: Text('Pacote não encontrado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do pacote')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _LabelPhoto(path: package.labelPhotoPath),
          const SizedBox(height: 16),
          Row(
            children: [
              StatusChip(package.status),
              const Spacer(),
              Icon(
                package.carrier.icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(package.carrier.label),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(package: package),
          if (package.notes != null) ...[
            const SizedBox(height: 12),
            _NotesCard(notes: package.notes!),
          ],
          const SizedBox(height: 24),
          Text(
            'Histórico',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _Timeline(events: package.events),
        ],
      ),
      bottomNavigationBar: _ActionBar(package: package),
    );
  }
}

class _LabelPhoto extends StatelessWidget {
  const _LabelPhoto({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = path != null ? File(path!) : null;

    if (file == null || !file.existsSync()) {
      return Card(
        child: Container(
          height: 140,
          alignment: Alignment.center,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                'Sem foto da etiqueta',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Image.file(
        file,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.package});

  final Package package;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.qr_code,
              label: 'Código',
              value: package.trackingCode,
            ),
            _InfoRow(
              icon: Icons.apartment_outlined,
              label: 'Unidade',
              value: package.unit ?? 'Não identificada',
            ),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Morador',
              value: package.recipientName ?? 'Não identificado',
            ),
            _InfoRow(
              icon: Icons.login_outlined,
              label: 'Recebido',
              value:
                  '${formatFullDateTime(package.receivedAt)}'
                  '\npor ${package.receivedBy}',
            ),
            if (package.deliveredAt != null)
              _InfoRow(
                icon: Icons.logout_outlined,
                label: package.status == PackageStatus.returned
                    ? 'Devolvido'
                    : 'Entregue',
                value:
                    formatFullDateTime(package.deliveredAt!) +
                    (package.pickedUpBy != null
                        ? '\npara ${package.pickedUpBy}'
                        : ''),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notes,
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<PackageEvent> events;

  @override
  Widget build(BuildContext context) {
    // Mais recente primeiro.
    final ordered = events.reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          children: [
            for (var i = 0; i < ordered.length; i++)
              _EventTile(event: ordered[i], isLast: i == ordered.length - 1),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.isLast});

  final PackageEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  event.type.icon,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 12 : 18, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.type.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatFullDateTime(event.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (event.actor != null)
                    Text(
                      event.actor!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.package});

  final Package package;

  @override
  Widget build(BuildContext context) {
    final Widget? action = switch (package.status) {
      PackageStatus.awaitingPickup => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => context.push('/packages/${package.id}/deliver'),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Registrar entrega'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/packages/${package.id}/return'),
            icon: const Icon(Icons.undo),
            label: const Text('Registrar devolução'),
          ),
        ],
      ),
      PackageStatus.pendingIdentification => FilledButton.icon(
        onPressed: () => context.push('/packages/${package.id}/identify'),
        icon: const Icon(Icons.person_search_outlined),
        label: const Text('Identificar destinatário'),
      ),
      PackageStatus.delivered ||
      PackageStatus.returned ||
      PackageStatus.canceled => null,
    };

    if (action == null) return const SizedBox.shrink();

    return SafeArea(minimum: const EdgeInsets.all(16), child: action);
  }
}
