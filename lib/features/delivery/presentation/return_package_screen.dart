import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/session_providers.dart';
import '../../packages/application/packages_providers.dart';
import '../../packages/domain/package.dart';

/// Confirmação de devolução de um pacote à transportadora.
class ReturnPackageScreen extends ConsumerStatefulWidget {
  const ReturnPackageScreen({super.key, required this.packageId});

  final String packageId;

  @override
  ConsumerState<ReturnPackageScreen> createState() =>
      _ReturnPackageScreenState();
}

class _ReturnPackageScreenState extends ConsumerState<ReturnPackageScreen> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm(Package package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar devolução'),
        content: Text(
          'O pacote de ${package.recipientName ?? "destinatário não identificado"} '
          'será marcado como devolvido à transportadora. Esta ação não pode ser '
          'desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final doorman = ref.read(currentDoormanProvider);
    final reason = _reasonController.text.trim();
    ref
        .read(packagesProvider.notifier)
        .markReturned(
          package.id,
          reason: reason.isEmpty ? null : reason,
          actor: doorman.name,
        );
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Devolução registrada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final package = ref.watch(packageByIdProvider(widget.packageId));

    if (package == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar devolução')),
        body: const Center(child: Text('Pacote não encontrado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar devolução')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PackageSummary(package: package),
          const SizedBox(height: 24),
          Text(
            'Motivo da devolução',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Opcional. Anotações úteis: morador recusou, '
            'endereço incorreto, prazo vencido.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ex.: morador recusou a entrega.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => _confirm(package),
          icon: const Icon(Icons.undo),
          label: const Text('Confirmar devolução'),
        ),
      ),
    );
  }
}

/// Resumo do pacote exibido no topo da tela.
class _PackageSummary extends StatelessWidget {
  const _PackageSummary({required this.package});

  final Package package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = package.isIdentified
        ? '${package.unit} · ${package.recipientName}'
        : 'Destinatário não identificado';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                package.carrier.icon,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${package.carrier.label} · ${package.trackingCode}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
