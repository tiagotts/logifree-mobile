import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../config/env.dart';

/// Loga requests, respostas e erros HTTP via `dart:developer`.
///
/// **No-op em produção** — só registra logs quando `Env.isDevelopment`
/// é `true`. Em release o overhead é apenas o método-chamada, sem I/O.
///
/// Em desenvolvimento, dumpa também body de request, body de response e
/// detalhe do erro (status + payload retornado pelo back) — útil pra
/// diagnosticar formato de DTO, falhas de parse, etc.
///
/// Não usa `print` (proibido pelos lints — `avoid_print`).
class LoggingInterceptor extends Interceptor {
  /// Cria um [LoggingInterceptor].
  ///
  /// O parâmetro opcional [isDevelopment] existe pra testes — em
  /// produção/dev real, deixa default que lê `Env.isDevelopment`.
  LoggingInterceptor({bool? isDevelopment})
    : _isDevelopment = isDevelopment ?? Env.isDevelopment;

  final bool _isDevelopment;

  static const String _loggerName = 'logifree.http';

  /// Caracteres máximos por corpo logado, pra não estourar o logcat.
  static const int _maxBodyChars = 4000;

  String _truncate(String value) =>
      value.length <= _maxBodyChars
      ? value
      : '${value.substring(0, _maxBodyChars)}... (truncado)';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isDevelopment) {
      developer.log('--> ${options.method} ${options.uri}', name: _loggerName);
      if (options.data != null) {
        developer.log(
          '    body: ${_truncate(options.data.toString())}',
          name: _loggerName,
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_isDevelopment) {
      developer.log(
        '<-- ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.uri}',
        name: _loggerName,
      );
      if (response.data != null) {
        developer.log(
          '    body: ${_truncate(response.data.toString())}',
          name: _loggerName,
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isDevelopment) {
      developer.log(
        '<-- ERR ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.method} ${err.requestOptions.uri}',
        name: _loggerName,
      );
      developer.log('    type: ${err.type}', name: _loggerName);
      if (err.message != null) {
        developer.log('    message: ${err.message}', name: _loggerName);
      }
      if (err.response?.data != null) {
        developer.log(
          '    response body: ${_truncate(err.response!.data.toString())}',
          name: _loggerName,
        );
      }
      if (err.error != null) {
        developer.log(
          '    inner error: ${err.error} (${err.error.runtimeType})',
          name: _loggerName,
        );
      }
    }
    handler.next(err);
  }
}
