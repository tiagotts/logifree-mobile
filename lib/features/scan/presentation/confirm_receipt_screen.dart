import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../packages/application/packages_providers.dart';
import '../../packages/application/units_provider.dart';
import '../../packages/data/dto/receive_package_request.dart';
import '../../packages/data/dto/unit_dto.dart';
import '../../packages/data/package_repository.dart';
import '../../packages/domain/carrier.dart';
import '../domain/scan_capture.dart';

/// Conferência dos dados extraídos antes de registrar a encomenda.
class ConfirmReceiptScreen extends ConsumerStatefulWidget {
  const ConfirmReceiptScreen({super.key, required this.capture});

  final ScanCapture capture;

  @override
  ConsumerState<ConfirmReceiptScreen> createState() =>
      _ConfirmReceiptScreenState();
}

class _ConfirmReceiptScreenState extends ConsumerState<ConfirmReceiptScreen> {
  late final TextEditingController _trackingController;
  late final TextEditingController _recipientController;
  final TextEditingController _notesController = TextEditingController();

  late Carrier _carrier;
  UnitDto? _selectedUnit;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final label = widget.capture.label;
    _trackingController = TextEditingController(text: label.trackingCode ?? '');
    _recipientController = TextEditingController(
      text: label.recipientName ?? '',
    );
    _carrier = label.carrier ?? Carrier.other;

    // Tenta pré-selecionar a unidade depois que a lista do back chega.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePreselectUnit());
  }

  Future<void> _maybePreselectUnit() async {
    final parsedUnit = widget.capture.label.unit;
    if (parsedUnit == null) return;
    try {
      final units = await ref.read(unitsProvider.future);
      if (!mounted) return;
      final target = parsedUnit.toLowerCase();
      for (final unit in units) {
        if (unit.displayName.toLowerCase() == target) {
          setState(() => _selectedUnit = unit);
          break;
        }
      }
    } on Object {
      // Falha em carregar unidades não bloqueia a tela — porteiro
      // ainda pode selecionar manualmente assim que a lista chegar.
    }
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _recipientController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final unit = _selectedUnit;
    if (unit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a unidade do destinatário.')),
      );
      return;
    }
    final tracking = _trackingController.text.trim();
    if (tracking.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código de rastreio.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final notes = _notesController.text.trim();
    final repo = ref.read(packageRepositoryProvider);

    try {
      await repo.receive(
        ReceivePackageRequest(
          trackingCode: tracking,
          unitId: unit.id,
          description: notes.isEmpty ? null : notes,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final err = e.error;
      final message = err is AppError
          ? err.userMessage
          : 'Não foi possível registrar a encomenda. Tente novamente.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      setState(() => _submitting = false);
      return;
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar a encomenda.'),
        ),
      );
      setState(() => _submitting = false);
      return;
    }

    if (!mounted) return;

    // Refaz o GET /packages para a Home/Lista enxergarem o pacote novo.
    // Não esperamos o resultado — a UX volta pra Home imediatamente.
    unawaited(ref.read(packagesProvider.notifier).refresh());

    context.go('/home');
    messenger.showSnackBar(
      const SnackBar(content: Text('Encomenda registrada com sucesso.')),
    );
  }

  void _openPhoto() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.file(File(widget.capture.photoPath)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar recebimento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.capture.label.hasRecipient) ...[
            const _ParsedBanner(),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _openPhoto,
            child: Card(
              child: Stack(
                children: [
                  Image.file(
                    File(widget.capture.photoPath),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: Chip(
                      avatar: Icon(Icons.zoom_in, size: 18),
                      label: Text('Ampliar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Encomenda'),
          const SizedBox(height: 10),
          DropdownMenu<Carrier>(
            initialSelection: _carrier,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Transportadora'),
            leadingIcon: Icon(_carrier.icon),
            onSelected: (carrier) {
              if (carrier != null) setState(() => _carrier = carrier);
            },
            dropdownMenuEntries: [
              for (final carrier in Carrier.values)
                DropdownMenuEntry(
                  value: carrier,
                  label: carrier.label,
                  leadingIcon: Icon(carrier.icon),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _trackingController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código de rastreio',
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Destinatário'),
          const SizedBox(height: 4),
          Text(
            'Selecione a unidade. O morador é notificado automaticamente '
            'pelo back ao registrar.',
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
          const SizedBox(height: 14),
          TextField(
            controller: _recipientController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome do morador (opcional)',
              prefixIcon: Icon(Icons.person_outline),
              helperText:
                  'Usado só para registro local; o back identifica '
                  'pelo cadastro da unidade.',
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Observações'),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Opcional: caixa grande, frágil, etc.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _submitting ? null : _confirm,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.check),
          label: Text(
            _submitting ? 'Registrando...' : 'Confirmar recebimento',
          ),
        ),
      ),
    );
  }
}

/// Dropdown de unidade que lida com o estado async (loading/error/data).
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

/// Aviso de que os campos foram preenchidos a partir da leitura da etiqueta.
class _ParsedBanner extends StatelessWidget {
  const _ParsedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Preenchemos os campos com a leitura da etiqueta. '
                'Confira antes de registrar.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
