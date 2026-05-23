import 'dart:convert';

/// Estado atual de uma operação enfileirada para sincronização offline.
///
/// Transições válidas:
/// - `pending` → `sending` (quando o [SyncService] inicia a drenagem)
/// - `sending` → `pending` (falha transitória; será tentado novamente)
/// - `sending` → `failed` (falha definitiva após `maxAttempts`)
/// - qualquer → removido (sucesso: a linha é deletada da fila)
enum PendingOperationStatus {
  /// Aguardando a próxima oportunidade de drenagem.
  pending,

  /// O [SyncService] está enviando esta operação agora.
  sending,

  /// Atingiu o limite de tentativas e não será mais retentada
  /// automaticamente. Usuário pode descartar manualmente.
  failed;

  /// Serializa para a coluna `status` do SQLite.
  String toDbValue() => name;

  /// Deserializa a coluna `status` do SQLite.
  ///
  /// Lança [ArgumentError] se o valor não corresponder a nenhum membro
  /// — preferimos falhar alto a aceitar lixo silenciosamente.
  static PendingOperationStatus fromDbValue(String value) {
    for (final PendingOperationStatus status in PendingOperationStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    throw ArgumentError('Unknown PendingOperationStatus: $value');
  }
}

/// Operação HTTP mutadora que foi capturada pelo
/// [OfflineFallbackInterceptor] e está aguardando sincronização.
///
/// **Imutável** — toda mutação produz uma nova instância via [copyWith].
/// Construída à mão (sem `freezed`) por decisão do projeto.
class PendingOperation {
  /// Cria uma [PendingOperation].
  const PendingOperation({
    required this.id,
    required this.method,
    required this.url,
    required this.idempotencyKey,
    required this.createdAt,
    required this.headers,
    required this.body,
    required this.attempts,
    required this.status,
    this.lastError,
  });

  /// Constrói a partir de uma linha do SQLite.
  ///
  /// Aceita `Map<String, Object?>` (formato canônico do sqflite). Faz
  /// parsing tolerante: campos opcionais podem estar ausentes ou nulos.
  factory PendingOperation.fromRow(Map<String, Object?> row) {
    final String? headersJson = row['headers'] as String?;
    final String? bodyJson = row['body'] as String?;

    return PendingOperation(
      id: row['id']! as String,
      method: row['method']! as String,
      url: row['url']! as String,
      headers: _decodeMap(headersJson),
      body: _decodeAny(bodyJson),
      idempotencyKey: row['idempotency_key']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at']! as int,
        isUtc: true,
      ),
      attempts: row['attempts']! as int,
      status: PendingOperationStatus.fromDbValue(row['status']! as String),
      lastError: row['last_error'] as String?,
    );
  }

  /// Identificador único da operação. Recomenda-se UUID v7 para
  /// preservar ordenação cronológica.
  final String id;

  /// Método HTTP (`POST`, `PUT`, `PATCH`, `DELETE`).
  final String method;

  /// URL completa ou relativa (como veio do Dio).
  final String url;

  /// Headers HTTP serializáveis. Não armazenamos `Authorization` aqui
  /// — o [SyncService] reanexa o header de auth no momento do envio.
  final Map<String, Object?> headers;

  /// Corpo da request. Pode ser `Map`, `List` ou tipo primitivo. Para
  /// `null` (sem body), use mapa/lista vazios conforme convenção do
  /// chamador.
  final Object? body;

  /// Chave de idempotência (header `Idempotency-Key`). Garante que
  /// retentativas não dupliquem o efeito no servidor.
  final String idempotencyKey;

  /// Momento em que a operação foi enfileirada (UTC).
  ///
  /// Usado para ordenação determinística na drenagem (FIFO).
  final DateTime createdAt;

  /// Quantidade de tentativas já feitas pelo [SyncService].
  final int attempts;

  /// Estado atual. Veja [PendingOperationStatus].
  final PendingOperationStatus status;

  /// Mensagem da última falha (apenas informativo).
  final String? lastError;

  /// Retorna uma cópia com os campos sobrescritos.
  ///
  /// Use sentinelas explicitamente para "limpar" campos opcionais:
  /// passe `clearLastError: true` para zerar [lastError].
  PendingOperation copyWith({
    String? id,
    String? method,
    String? url,
    Map<String, Object?>? headers,
    Object? body,
    String? idempotencyKey,
    DateTime? createdAt,
    int? attempts,
    PendingOperationStatus? status,
    String? lastError,
    bool clearLastError = false,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  /// Serializa para o formato de linha do SQLite.
  Map<String, Object?> toRow() {
    return <String, Object?>{
      'id': id,
      'method': method,
      'url': url,
      'headers': jsonEncode(headers),
      'body': body == null ? null : jsonEncode(body),
      'idempotency_key': idempotencyKey,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'attempts': attempts,
      'status': status.toDbValue(),
      'last_error': lastError,
    };
  }

  /// Serializa para JSON (útil em logs/testes — não para persistência).
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'method': method,
      'url': url,
      'headers': headers,
      'body': body,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'attempts': attempts,
      'status': status.toDbValue(),
      'lastError': lastError,
    };
  }

  /// Constrói a partir de JSON (espelho de [toJson]).
  factory PendingOperation.fromJson(Map<String, Object?> json) {
    return PendingOperation(
      id: json['id']! as String,
      method: json['method']! as String,
      url: json['url']! as String,
      headers: Map<String, Object?>.from(
        (json['headers'] as Map<Object?, Object?>?) ?? <Object, Object>{},
      ),
      body: json['body'],
      idempotencyKey: json['idempotencyKey']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
      attempts: json['attempts']! as int,
      status: PendingOperationStatus.fromDbValue(json['status']! as String),
      lastError: json['lastError'] as String?,
    );
  }

  static Map<String, Object?> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, Object?>{};
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map<Object?, Object?>) {
      return decoded.map(
        (Object? k, Object? v) => MapEntry<String, Object?>(k! as String, v),
      );
    }
    return <String, Object?>{};
  }

  static Object? _decodeAny(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw);
  }

  @override
  String toString() =>
      'PendingOperation(id: $id, method: $method, url: $url, '
      'status: ${status.name}, attempts: $attempts)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PendingOperation &&
        other.id == id &&
        other.method == method &&
        other.url == url &&
        other.idempotencyKey == idempotencyKey &&
        other.createdAt == createdAt &&
        other.attempts == attempts &&
        other.status == status &&
        other.lastError == lastError;
  }

  @override
  int get hashCode => Object.hash(
    id,
    method,
    url,
    idempotencyKey,
    createdAt,
    attempts,
    status,
    lastError,
  );
}
