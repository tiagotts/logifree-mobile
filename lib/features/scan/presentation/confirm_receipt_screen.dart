import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/doorman.dart';
import '../../packages/application/packages_providers.dart';
import '../../packages/domain/carrier.dart';
import '../../packages/domain/package.dart';
import '../../packages/domain/package_event.dart';
import '../../packages/domain/package_status.dart';
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
  late final TextEditingController _unitController;
  final TextEditingController _notesController = TextEditingController();

  late Carrier _carrier;

  @override
  void initState() {
    super.initState();
    // Pré-preenche os campos com o que o LabelParser identificou na etiqueta.
    final label = widget.capture.label;
    _trackingController = TextEditingController(text: label.trackingCode ?? '');
    _recipientController = TextEditingController(
      text: label.recipientName ?? '',
    );
    _unitController = TextEditingController(text: label.unit ?? '');
    _carrier = label.carrier ?? Carrier.other;
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _recipientController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _confirm() {
    final now = DateTime.now();
    final recipient = _recipientController.text.trim();
    final unit = _unitController.text.trim();
    final tracking = _trackingController.text.trim();
    final notes = _notesController.text.trim();
    final isIdentified = recipient.isNotEmpty && unit.isNotEmpty;

    final package = Package(
      id: 'pkg-${now.microsecondsSinceEpoch.toRadixString(36)}',
      trackingCode: tracking.isEmpty ? 'Sem código' : tracking,
      carrier: _carrier,
      status: isIdentified
          ? PackageStatus.awaitingPickup
          : PackageStatus.pendingIdentification,
      receivedAt: now,
      receivedBy: demoDoorman.name,
      recipientName: isIdentified ? recipient : null,
      unit: isIdentified ? unit : null,
      notes: notes.isEmpty ? null : notes,
      labelPhotoPath: widget.capture.photoPath,
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: now,
          actor: demoDoorman.name,
        ),
        if (isIdentified)
          PackageEvent(
            type: PackageEventType.identified,
            timestamp: now,
            actor: demoDoorman.name,
          ),
      ],
    );

    ref.read(packagesProvider.notifier).register(package);

    context.go('/home');
    ScaffoldMessenger.of(context).showSnackBar(
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

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar recebimento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.capture.label.hasRecipient) ...[
            _ParsedBanner(),
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
          _SectionLabel('Encomenda'),
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
          _SectionLabel('Destinatário'),
          const SizedBox(height: 4),
          Text(
            'Confira os dados lidos da etiqueta. Se ficarem em branco, a '
            'encomenda entra como pendente de identificação.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Unidade',
              hintText: 'Ex.: Apto 101',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _recipientController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome do morador',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Observações'),
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
          onPressed: _confirm,
          icon: const Icon(Icons.check),
          label: const Text('Confirmar recebimento'),
        ),
      ),
    );
  }
}

/// Aviso de que os campos foram preenchidos a partir da leitura da etiqueta.
class _ParsedBanner extends StatelessWidget {
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
