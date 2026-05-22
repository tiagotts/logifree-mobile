import '../../packages/domain/carrier.dart';
import '../data/ocr_result.dart';
import 'parsed_label.dart';

/// Extrai destinatário, unidade e código de rastreio do texto de uma etiqueta.
///
/// Usa heurística por palavras-chave e regex — cobre os formatos mais comuns
/// de etiqueta no Brasil. O parser definitivo, por transportadora, é o
/// CARD-MOBILE-012 do backlog.
abstract final class LabelParser {
  const LabelParser._();

  static ParsedLabel parse(OcrResult ocr) {
    final text = ocr.text ?? '';
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final tracking = _trackingCode(ocr, text);

    return ParsedLabel(
      recipientName: _recipientName(lines),
      unit: _unit(text),
      trackingCode: tracking,
      carrier: _carrier(tracking),
    );
  }

  // --- Destinatário ---------------------------------------------------------

  /// Indica que a linha trata do destinatário.
  static final RegExp _recipientLine = RegExp(
    'destinat|recebedor',
    caseSensitive: false,
  );

  /// Remove tudo até o rótulo de destinatário, sobrando só o possível nome.
  static final RegExp _recipientLabel = RegExp(
    r'^.*?(?:destinat\S*|recebedor)\s*:?\s*',
    caseSensitive: false,
  );

  /// Palavras que aparecem em etiquetas mas nunca são nome de pessoa.
  static const Set<String> _nonNameWords = {
    'RUA',
    'AVENIDA',
    'AV',
    'ALAMEDA',
    'TRAVESSA',
    'RODOVIA',
    'ESTRADA',
    'BAIRRO',
    'CIDADE',
    'ESTADO',
    'CEP',
    'BRASIL',
    'CORREIOS',
    'OBJETO',
    'REMETENTE',
    'DESTINATARIO',
    'DESTINATÁRIO',
    'NUMERO',
    'NÚMERO',
    'COMPLEMENTO',
    'QUADRA',
    'LOTE',
    'BLOCO',
    'CONDOMINIO',
    'CONDOMÍNIO',
    'ENTREGA',
    'PEDIDO',
    'NOTA',
    'FISCAL',
    'TRANSPORTADORA',
  };

  static final RegExp _nameWord = RegExp(r'^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ.]*$');

  static String? _recipientName(List<String> lines) {
    // 1. Linha com rótulo "Destinatário"/"Recebedor".
    for (var i = 0; i < lines.length; i++) {
      if (!_recipientLine.hasMatch(lines[i])) continue;

      // Nome na mesma linha, após o rótulo.
      final inline = lines[i].replaceFirst(_recipientLabel, '').trim();
      if (_looksLikeName(inline)) return _titleCase(inline);

      // Senão, nas duas linhas seguintes.
      for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
        if (_looksLikeName(lines[j])) return _titleCase(lines[j]);
      }
    }

    // 2. Sem rótulo: a primeira linha que pareça um nome.
    for (final line in lines) {
      if (_looksLikeName(line)) return _titleCase(line);
    }
    return null;
  }

  static bool _looksLikeName(String value) {
    final clean = value.trim();
    if (clean.length < 6 || clean.length > 45) return false;

    final words = clean.split(RegExp(r'\s+'));
    if (words.length < 2 || words.length > 5) return false;

    for (final word in words) {
      if (!_nameWord.hasMatch(word)) return false;
      if (_nonNameWords.contains(word.toUpperCase())) return false;
    }
    return true;
  }

  // --- Unidade --------------------------------------------------------------

  static final RegExp _unitPattern = RegExp(
    r'\b(?:ap|apt|apto|apart(?:amento)?|unid(?:ade)?|casa)\b'
    r'[\s.:n°º\-]*(\d{1,5})\b',
    caseSensitive: false,
  );

  static String? _unit(String text) {
    final match = _unitPattern.firstMatch(text);
    if (match == null) return null;
    return 'Apto ${match.group(1)}';
  }

  // --- Código de rastreio ---------------------------------------------------

  static final List<RegExp> _trackingPatterns = [
    RegExp(r'\b[A-Z]{2}\d{9}[A-Z]{2}\b'),
    RegExp(r'\bMLB\d{6,}\b', caseSensitive: false),
    RegExp(r'\bTBA\d{6,}\b', caseSensitive: false),
    RegExp(r'\bSPX[A-Z]{2}\d{6,}\b', caseSensitive: false),
  ];

  static String? _trackingCode(OcrResult ocr, String text) {
    if (ocr.barcodes.isNotEmpty) return ocr.barcodes.first;
    for (final pattern in _trackingPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(0)!.toUpperCase();
    }
    return null;
  }

  // --- Transportadora -------------------------------------------------------

  static Carrier? _carrier(String? code) {
    if (code == null) return null;
    final c = code.toUpperCase();
    if (c.startsWith('MLB')) return Carrier.mercadoLivre;
    if (c.startsWith('TBA')) return Carrier.amazon;
    if (c.startsWith('SPX')) return Carrier.shopee;
    if (c.startsWith('BR') && c.endsWith('BR')) return Carrier.correios;
    return Carrier.other;
  }

  // --- Utilitário -----------------------------------------------------------

  static String _titleCase(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
