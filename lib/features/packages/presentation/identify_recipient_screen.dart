import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/session_providers.dart';
import '../application/packages_providers.dart';
import '../application/units_provider.dart';
import '../data/dto/unit_dto.dart';
import '../domain/package.dart';

/// Identificação manual do destinatário de um pacote pendente.
///
/// Acessível pela tela de detalhes quando o pacote está em
/// `PackageStatus.pendingIdentification`.
class IdentifyRecipientScreen extends ConsumerStatefulWidget {
  const IdentifyRecipientScreen({super.key, required this.packageId});

  final String packageId;

  @override
  ConsumerState<IdentifyRecipientScreen> createState() =>
      _IdentifyRecipientScreenState();
}

class _IdentifyRecipientScreenState
    extends ConsumerState<IdentifyRecipientScreen> {
  final TextEditingController _residentController = TextEditingController();
  UnitDto? _selectedUnit;

  @override
  void dispose() {
    _residentController.dispose();
    super.dispose();
  }

  void _confirm(Package package) {
    final unit = _selectedUnit;
    final resident = _residentController.text.trim();
    if (unit == null || resident.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final doorman = ref.read(currentDoormanProvider);
    ref
        .read(packagesProvider.notifier)
        .identify(
          package.id,
          recipientName: resident,
          unit: unit.displayName,
          actor: doorman.name,
        );
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Destinatário identificado.')),
    );
  }

  void _skip() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final package = ref.watch(packageByIdProvider(widget.packageId));
    final unitsAsync = ref.watch(unitsProvider);

    if (package == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Identificar destinatário')),
        body: const Center(child: Text('Pacote não encontrado.')),
      );
    }

    final canConfirm =
        _selectedUnit != null && _residentController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Identificar destinatário')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PackageSummary(package: package),
          const SizedBox(height: 24),
          Text(
            'Selecione a unidade',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Procure pelo número do apartamento, casa ou cobertura.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _UnitField(
            unitsAsync: unitsAsync,
            selected: _selectedUnit,
            onChanged: (unit) => setState(() => _selectedUnit = unit),
            onRetry: () => ref.invalidate(unitsProvider),
          ),
          const SizedBox(height: 24),
          Text(
            'Quem é o morador?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Digite o nome do morador a quem o pacote pertence.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _residentController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nome do morador',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: canConfirm ? () => _confirm(package) : null,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar identificação'),
            ),
            TextButton(
              onPressed: _skip,
              child: const Text('Não consigo identificar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown de unidade reagindo ao estado async do `unitsProvider`.
class _UnitField extends StatelessWidget {
  const _UnitField({
    required this.unitsAsync,
    required this.selected,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<List<UnitDto>> unitsAsync;
  final UnitDto? selected;
  final ValueChanged<UnitDto?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return unitsAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Unidade',
          prefixIcon: Icon(Icons.apartment_outlined),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Carregando unidades...'),
          ],
        ),
      ),
      error: (e, _) => Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Não foi possível carregar a lista de unidades.',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
      data: (units) => DropdownMenu<UnitDto>(
        initialSelection: selected,
        expandedInsets: EdgeInsets.zero,
        enableFilter: true,
        requestFocusOnTap: true,
        label: const Text('Unidade'),
        leadingIcon: const Icon(Icons.apartment_outlined),
        menuHeight: 320,
        onSelected: onChanged,
        dropdownMenuEntries: [
          for (final unit in units)
            DropdownMenuEntry<UnitDto>(
              value: unit,
              label: unit.displayName,
            ),
        ],
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
                    'Pacote pendente de identificação',
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
