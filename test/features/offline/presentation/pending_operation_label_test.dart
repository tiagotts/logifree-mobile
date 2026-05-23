import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/offline/pending_operation.dart';
import 'package:logifree_mobile/features/offline/presentation/pending_operation_label.dart';

void main() {
  PendingOperation op(String method, String url) {
    return PendingOperation(
      id: 'x',
      method: method,
      url: url,
      headers: const <String, Object?>{},
      body: const <String, Object?>{},
      idempotencyKey: 'k',
      createdAt: DateTime.utc(2026, 5, 23),
      attempts: 0,
      status: PendingOperationStatus.pending,
    );
  }

  group('describePendingOperation', () {
    test('POST /packages vira "Recebimento de pacote"', () {
      expect(
        describePendingOperation(op('POST', '/api/v1/packages')),
        'Recebimento de pacote',
      );
    });

    test('POST /packages/:id/deliver vira "Entrega de pacote"', () {
      expect(
        describePendingOperation(
          op('POST', '/api/v1/packages/abc-123/deliver'),
        ),
        'Entrega de pacote',
      );
    });

    test('POST /packages/:id/return vira "Devolução de pacote"', () {
      expect(
        describePendingOperation(op('POST', '/api/v1/packages/abc-123/return')),
        'Devolução de pacote',
      );
    });

    test(
      'POST /packages/:id/identify vira "Identificação de destinatário"',
      () {
        expect(
          describePendingOperation(
            op('POST', '/api/v1/packages/abc-123/identify'),
          ),
          'Identificação de destinatário',
        );
      },
    );

    test('PATCH /packages/:id vira "Atualização de pacote"', () {
      expect(
        describePendingOperation(op('PATCH', '/api/v1/packages/abc-123')),
        'Atualização de pacote',
      );
    });

    test('rota desconhecida cai no fallback por método', () {
      expect(
        describePendingOperation(op('POST', '/api/v1/foo/bar')),
        contains('Criação'),
      );
    });
  });
}
