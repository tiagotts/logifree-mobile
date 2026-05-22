import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../packages/application/packages_providers.dart';
import '../../packages/domain/package.dart';

/// Confirmação de retirada de um pacote pelo morador.
class DeliverPackageScreen extends ConsumerStatefulWidget {
  const DeliverPackageScreen({super.key, required this.packageId});

  final String packageId;

  @override
  ConsumerState<DeliverPackageScreen> createState() =>
      _DeliverPackageScreenState();
}

class _DeliverPackageScreenState extends ConsumerState<DeliverPackageScreen> {
  final TextEditingController _pickedUpByController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _prefilled = false;

  @override
  void dispose() {
    _pickedUpByController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirm(Package package) {
    final messenger = ScaffoldMessenger.of(context);
    ref
        .read(packagesProvider.notifier)
        .deliver(
          package.id,
          pickedUpBy: _pickedUpByController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Entrega registrada com sucesso.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final package = ref.watch(packageByIdProvider(widget.packageId));

    if (package == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar entrega')),
        body: const Center(child: Text('Pacote não encontrado.')),
      );
    }

    // Pré-preenche "quem retirou" com o morador identificado.
    if (!_prefilled) {
      _prefilled = true;
      _pickedUpByController.text = package.recipientName ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar entrega')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PackageSummary(package: package),
          const SizedBox(height: 24),
          Text(
            'Quem retirou o pacote?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pickedUpByController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome de quem retirou',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Observações',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Opcional'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _pickedUpByController,
          builder: (context, value, _) {
            final enabled = value.text.trim().isNotEmpty;
            return FilledButton.icon(
              onPressed: enabled ? () => _confirm(package) : null,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar entrega'),
            );
          },
        ),
      ),
    );
  }
}

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
