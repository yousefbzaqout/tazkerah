import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Logs request and response metadata in non-production builds.
///
/// Bodies and sensitive headers are never logged. Request bodies carry
/// passwords and payment details; responses carry tokens and grants; on
/// Android any app holding log permissions could read them. Method, path,
/// status and timing are enough to debug with, and safe to write down.
///
/// [AppConfig.enableNetworkLogging] gates installation, so this never reaches
/// a production build at all.
class LoggingInterceptor extends Interceptor {
  static const Set<String> _redactedHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'idempotency-key',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_startedAt'] = DateTime.now();
    developer.log('→ ${options.method} ${options.uri}', name: 'network');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.uri} '
      '(${_elapsed(response.requestOptions)})',
      name: 'network',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '✗ ${err.type.name} ${err.requestOptions.uri} '
      '${err.response?.statusCode ?? ''} (${_elapsed(err.requestOptions)})',
      name: 'network',
      error: err.message,
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final startedAt = options.extra['_startedAt'];
    if (startedAt is! DateTime) return '?';
    return '${DateTime.now().difference(startedAt).inMilliseconds}ms';
  }

  /// Exposed for the day someone needs header logging: use this, never the
  /// raw map.
  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: _redactedHeaders.contains(entry.key.toLowerCase())
            ? '<redacted>'
            : entry.value,
    };
  }
}
