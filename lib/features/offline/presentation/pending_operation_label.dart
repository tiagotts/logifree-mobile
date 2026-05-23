import '../../../core/offline/pending_operation.dart';

/// Humaniza uma [PendingOperation] em um rótulo curto e em pt-BR para a UI.
///
/// Inspecciona o par `method` + `url` e tenta inferir a ação do usuário.
/// Quando nenhuma regra bate, devolve um fallback genérico baseado no
/// método HTTP — preferível a ficar mudo na tela.
String describePendingOperation(PendingOperation op) {
  final String method = op.method.toUpperCase();
  final String url = op.url;

  // Endpoints conhecidos do back. Ordem importa: rotas mais específicas
  // primeiro (ex.: `/packages/:id/deliver` antes de `/packages/:id`).
  if (method == 'POST' && _matches(url, RegExp(r'/packages/[^/]+/deliver$'))) {
    return 'Entrega de pacote';
  }
  if (method == 'POST' && _matches(url, RegExp(r'/packages/[^/]+/return$'))) {
    return 'Devolução de pacote';
  }
  if (method == 'POST' && _matches(url, RegExp(r'/packages/[^/]+/identify$'))) {
    return 'Identificação de destinatário';
  }
  if (method == 'POST' && _matches(url, RegExp(r'/packages/[^/]+/cancel$'))) {
    return 'Cancelamento de pacote';
  }
  if (method == 'POST' && _matches(url, RegExp(r'/packages/?$'))) {
    return 'Recebimento de pacote';
  }
  if (method == 'PATCH' && _matches(url, RegExp(r'/packages/[^/]+/?$'))) {
    return 'Atualização de pacote';
  }
  if (method == 'DELETE' && _matches(url, RegExp(r'/packages/[^/]+/?$'))) {
    return 'Exclusão de pacote';
  }

  // Fallback por método HTTP.
  switch (method) {
    case 'POST':
      return 'Criação ($url)';
    case 'PUT':
    case 'PATCH':
      return 'Atualização ($url)';
    case 'DELETE':
      return 'Remoção ($url)';
    default:
      return '$method $url';
  }
}

bool _matches(String url, RegExp pattern) {
  // Aceita URL relativa (`/api/v1/packages`) ou absoluta — `pattern`
  // é casada como substring, então não importa o prefixo.
  return pattern.hasMatch(url);
}
