import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/api/api_error.dart';
import 'package:logifree_mobile/core/api/dio_client.dart';

/// Adapter de teste — implementa [HttpClientAdapter] retornando uma
/// sequência pré-definida de respostas/erros, sem rede real.
///
/// Cada chamada de `fetch` consome o próximo item da fila [responses].
/// Itens podem ser:
/// - `ResponseBody` → retorno normal.
/// - `DioException` → simula erro (timeout, falha de conexão etc.).
class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this.responses);

  final List<Object> responses;
  int callCount = 0;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    requests.add(options);
    if (responses.isEmpty) {
      throw StateError('No more queued responses');
    }
    final Object next = responses.removeAt(0);
    if (next is DioException) {
      throw next;
    }
    if (next is ResponseBody) {
      return next;
    }
    throw StateError('Unsupported queued response: $next');
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(int status, Map<String, dynamic> body) {
  final List<int> bytes = utf8.encode(jsonEncode(body));
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

void main() {
  group('createDioClient — base config', () {
    test('aplica baseUrl e timeouts padrão', () {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      expect(dio.options.baseUrl, 'https://api.test/v1');
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    });

    test(
      'injeta X-Condominium-Slug quando slugProvider retorna valor',
      () async {
        final Dio dio = createDioClient(
          baseUrl: 'https://api.test/v1',
          slugProvider: () => 'edificio-central',
        );
        final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
          _jsonBody(200, <String, dynamic>{'ok': true}),
        ]);
        dio.httpClientAdapter = adapter;

        await dio.get<dynamic>('/ping');

        expect(
          adapter.requests.single.headers['X-Condominium-Slug'],
          'edificio-central',
        );
      },
    );

    test(
      'não anexa X-Condominium-Slug quando slugProvider retorna null',
      () async {
        final Dio dio = createDioClient(
          baseUrl: 'https://api.test/v1',
          slugProvider: () => null,
        );
        final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
          _jsonBody(200, <String, dynamic>{'ok': true}),
        ]);
        dio.httpClientAdapter = adapter;

        await dio.get<dynamic>('/ping');

        expect(
          adapter.requests.single.headers.containsKey('X-Condominium-Slug'),
          isFalse,
        );
      },
    );
  });

  group('ErrorInterceptor — mapeamento para AppError', () {
    test('mapeia code INVALID_CREDENTIALS para userMessage pt-BR', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      dio.httpClientAdapter = _QueuedAdapter(<Object>[
        _jsonBody(401, <String, dynamic>{
          'error': 'AuthError',
          'message': 'Invalid credentials',
          'code': 'INVALID_CREDENTIALS',
          'requestId': 'req-123',
        }),
      ]);

      try {
        await dio.post<dynamic>('/auth/sign-in');
        fail('Expected DioException');
      } on DioException catch (e) {
        expect(e.error, isA<AppError>());
        final AppError err = e.error! as AppError;
        expect(err.code, 'INVALID_CREDENTIALS');
        expect(err.userMessage, 'E-mail ou senha inválidos.');
        expect(err.requestId, 'req-123');
      }
    });

    test('mapeia code VALIDATION_ERROR com details', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      dio.httpClientAdapter = _QueuedAdapter(<Object>[
        _jsonBody(400, <String, dynamic>{
          'error': 'ValidationError',
          'message': 'Invalid fields',
          'code': 'VALIDATION_ERROR',
          'details': <String, dynamic>{
            'fields': <String>['email'],
          },
        }),
      ]);

      try {
        await dio.post<dynamic>('/anything');
        fail('Expected DioException');
      } on DioException catch (e) {
        final AppError err = e.error! as AppError;
        expect(err.code, 'VALIDATION_ERROR');
        expect(err.userMessage, 'Dados inválidos. Confira os campos.');
        expect(err.details, isNotNull);
        expect(err.details!['fields'], <String>['email']);
      }
    });

    test('fallback genérico quando code não está mapeado', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      dio.httpClientAdapter = _QueuedAdapter(<Object>[
        _jsonBody(400, <String, dynamic>{
          'error': 'WeirdError',
          'message': 'Something odd',
          'code': 'SOMETHING_NEW',
        }),
      ]);

      try {
        await dio.get<dynamic>('/anything');
        fail('Expected DioException');
      } on DioException catch (e) {
        final AppError err = e.error! as AppError;
        expect(err.code, 'SOMETHING_NEW');
        expect(
          err.userMessage,
          'Não foi possível completar a ação. Tente novamente.',
        );
      }
    });

    test(
      '5xx sem code vira SERVER_ERROR com mensagem de indisponibilidade',
      () async {
        final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
        // 5x respostas 500 sem body — o retry vai retentar uma vez e ainda
        // assim falhar. Por isso enfileiramos duas respostas iguais.
        dio.httpClientAdapter = _QueuedAdapter(<Object>[
          _jsonBody(500, <String, dynamic>{}),
          _jsonBody(500, <String, dynamic>{}),
        ]);

        try {
          await dio.get<dynamic>('/anything');
          fail('Expected DioException');
        } on DioException catch (e) {
          final AppError err = e.error! as AppError;
          expect(err.code, 'SERVER_ERROR');
          expect(err.userMessage, 'Serviço temporariamente indisponível.');
        }
      },
    );
  });

  group('RetryInterceptor', () {
    test(
      'retenta uma vez em 5xx e resolve quando segunda chamada retorna 200',
      () async {
        final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
        final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
          _jsonBody(503, <String, dynamic>{'error': 'temporary'}),
          _jsonBody(200, <String, dynamic>{'ok': true}),
        ]);
        dio.httpClientAdapter = adapter;

        final Response<dynamic> response = await dio.get<dynamic>('/ping');

        expect(response.statusCode, 200);
        expect(adapter.callCount, 2);
      },
    );

    test('retenta uma vez em timeout', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
        DioException(
          requestOptions: RequestOptions(path: '/ping'),
          type: DioExceptionType.receiveTimeout,
        ),
        _jsonBody(200, <String, dynamic>{'ok': true}),
      ]);
      dio.httpClientAdapter = adapter;

      final Response<dynamic> response = await dio.get<dynamic>('/ping');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('NÃO retenta em 4xx', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
        _jsonBody(400, <String, dynamic>{
          'error': 'ValidationError',
          'message': 'bad',
          'code': 'VALIDATION_ERROR',
        }),
      ]);
      dio.httpClientAdapter = adapter;

      try {
        await dio.get<dynamic>('/anything');
        fail('Expected DioException');
      } on DioException catch (_) {
        // Esperado.
      }

      expect(adapter.callCount, 1);
    });

    test('NÃO retenta em 401 (autorização)', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
        _jsonBody(401, <String, dynamic>{
          'error': 'AuthError',
          'message': 'nope',
          'code': 'INVALID_CREDENTIALS',
        }),
      ]);
      dio.httpClientAdapter = adapter;

      try {
        await dio.get<dynamic>('/anything');
        fail('Expected DioException');
      } on DioException catch (_) {}

      expect(adapter.callCount, 1);
    });

    test('retenta no máximo uma vez em 5xx (não duas)', () async {
      final Dio dio = createDioClient(baseUrl: 'https://api.test/v1');
      final _QueuedAdapter adapter = _QueuedAdapter(<Object>[
        _jsonBody(500, <String, dynamic>{}),
        _jsonBody(500, <String, dynamic>{}),
      ]);
      dio.httpClientAdapter = adapter;

      try {
        await dio.get<dynamic>('/anything');
        fail('Expected DioException');
      } on DioException catch (_) {}

      // 1 original + 1 retry = 2. Nada além disso.
      expect(adapter.callCount, 2);
    });
  });
}
