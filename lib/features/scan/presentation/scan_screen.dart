import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ocr_result.dart';
import '../data/ocr_service.dart';
import '../domain/label_parser.dart';
import '../domain/parsed_label.dart';
import '../domain/scan_capture.dart';

/// Captura da etiqueta da encomenda.
///
/// Reaproveita o POC de OCR (Google ML Kit via `image_picker`): o porteiro
/// fotografa a etiqueta, o app lê o texto, extrai destinatário/unidade/código
/// e segue para a conferência dos dados.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _imagePath;
  OcrResult? _result;
  ParsedLabel? _label;
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() {
        _imagePath = pickedFile.path;
        _result = null;
        _label = null;
        _isProcessing = true;
      });

      final result = await _ocrService.processImage(pickedFile.path);

      setState(() {
        _result = result;
        _label = LabelParser.parse(result);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _result = OcrResult(error: 'Erro ao selecionar imagem: $e');
        _label = null;
        _isProcessing = false;
      });
    }
  }

  void _continue() {
    final path = _imagePath;
    if (path == null) return;
    context.push(
      '/scan/confirm',
      extra: ScanCapture(
        photoPath: path,
        ocr: _result ?? const OcrResult(),
        label: _label ?? ParsedLabel.empty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canContinue = _imagePath != null && !_isProcessing;

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear etiqueta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fotografe a etiqueta da encomenda. O app lê o texto e '
                'identifica o destinatário automaticamente.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Câmera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeria'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_imagePath != null) ...[
                Card(
                  child: Image.file(
                    File(_imagePath!),
                    fit: BoxFit.cover,
                    height: 240,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Lendo etiqueta...'),
                    ],
                  ),
                ),
              if (_result != null && !_isProcessing)
                _OcrSummary(
                  result: _result!,
                  label: _label ?? ParsedLabel.empty,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: canContinue
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar para conferência'),
              ),
            )
          : null,
    );
  }
}

/// Resumo do que o OCR encontrou e do que o parser identificou na etiqueta.
class _OcrSummary extends StatelessWidget {
  const _OcrSummary({required this.result, required this.label});

  final OcrResult result;
  final ParsedLabel label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result.hasError) {
      return const _InfoCard(
        icon: Icons.error_outline,
        color: Color(0xFFB3261E),
        title: 'Não foi possível ler a etiqueta',
        message: 'Você ainda pode continuar e preencher os dados manualmente.',
      );
    }

    if (!result.hasData) {
      return const _InfoCard(
        icon: Icons.info_outline,
        color: Color(0xFF1565C0),
        title: 'Nada detectado na imagem',
        message: 'Tente outra foto ou continue preenchendo manualmente.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoCard(
          icon: Icons.check_circle_outline,
          color: Color(0xFF2E7D32),
          title: 'Etiqueta lida',
          message: 'Confira os dados identificados abaixo.',
        ),
        const SizedBox(height: 12),
        _IdentifiedCard(label: label),
        if (result.hasText) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Texto reconhecido',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(result.text!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Mostra destinatário, unidade e código que o parser conseguiu identificar.
class _IdentifiedCard extends StatelessWidget {
  const _IdentifiedCard({required this.label});

  final ParsedLabel label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dados identificados',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            _IdentifiedRow(
              icon: Icons.person_outline,
              label: 'Destinatário',
              value: label.recipientName,
            ),
            _IdentifiedRow(
              icon: Icons.apartment_outlined,
              label: 'Unidade',
              value: label.unit,
            ),
            _IdentifiedRow(
              icon: Icons.qr_code,
              label: 'Código',
              value: label.trackingCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentifiedRow extends StatelessWidget {
  const _IdentifiedRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    final found = value != null && value!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: onContainer),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onContainer.withValues(alpha: 0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              found ? value! : 'não identificado',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: found ? FontWeight.w700 : FontWeight.w400,
                color: found
                    ? onContainer
                    : onContainer.withValues(alpha: 0.55),
                fontStyle: found ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
