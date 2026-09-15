import 'dart:io';

import 'package:dio/dio.dart';

import 'failure.dart';

/// Translates transport-level exceptions into the app's [Failure] vocabulary.
///
/// This is the single boundary where Dio's types stop. Data sources call
/// [mapDioException]; everything above them deals only in [Failure].
abstract final class ErrorMapper {
  /// Converts a [DioException] into the matching [Failure].
  static Failure mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(debugMessage: e.message);

      case DioExceptionType.cancel:
        return CancelledFailure(debugMessage: e.message);

      case DioExceptionType.connectionError:
        return NetworkFailure(debugMessage: e.message);

      case DioExceptionType.badCertificate:
        // Treated as a network failure to the user, but this is security
        // relevant: it is also what a failed certificate pin looks like.
        return NetworkFailure(code: 'BAD_CERTIFICATE', debugMessage: e.message);

      case DioExceptionType.badResponse:
        return _mapStatusCode(e);

      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return NetworkFailure(debugMessage: e.message);
        }
        return UnknownFailure(debugMessage: e.message ?? e.error?.toString());
    }
  }

  static Failure _mapStatusCode(DioException e) {
    final response = e.response;
    final status = response?.statusCode;
    final envelope = _readEnvelope(response?.data);
    final code = envelope.code;
    final debug = envelope.message ?? e.message;

    return switch (status) {
      401 => UnauthorizedFailure(code: code, debugMessage: debug),
      403 => ForbiddenFailure(code: code, debugMessage: debug),
      404 => NotFoundFailure(code: code, debugMessage: debug),
      409 => ConflictFailure(code: code, debugMessage: debug),
      // A locked sector is its own outcome, not a generic failure: the seat
      // map offers alternatives rather than an error page.
      423 => LockedFailure(code: code, debugMessage: debug),
      422 => ValidationFailure(
        fieldErrors: envelope.fieldErrors,
        code: code,
        debugMessage: debug,
      ),
      429 => RateLimitFailure(
        retryAfter: _readRetryAfter(response),
        code: code,
        debugMessage: debug,
      ),
      final int s when s >= 500 => ServerFailure(
        statusCode: s,
        code: code,
        debugMessage: debug,
      ),
      _ => UnknownFailure(code: code, debugMessage: debug),
    };
  }

  /// Parses the agreed error envelope:
  /// `{"error": {"code": "...", "message": "...", "details": {...}}}`
  ///
  /// Deliberately forgiving — a malformed body must not itself throw, or we
  /// lose the original error behind a parsing crash.
  static _Envelope _readEnvelope(Object? data) {
    if (data is! Map) return const _Envelope();

    final error = data['error'];
    if (error is! Map) return const _Envelope();

    final code = error['code'];
    final message = error['message'];
    final details = error['details'];

    return _Envelope(
      code: code is String ? code : null,
      message: message is String ? message : null,
      fieldErrors: _readFieldErrors(details),
    );
  }

  static Map<String, List<String>> _readFieldErrors(Object? details) {
    if (details is! Map) return const {};

    final result = <String, List<String>>{};
    details.forEach((key, value) {
      if (key is! String) return;
      if (value is List) {
        result[key] = value.whereType<String>().toList(growable: false);
      } else if (value is String) {
        result[key] = [value];
      }
    });
    return result;
  }

  static Duration? _readRetryAfter(Response<dynamic>? response) {
    final header = response?.headers.value('retry-after');
    if (header == null) return null;
    final seconds = int.tryParse(header);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

class _Envelope {
  const _Envelope({this.code, this.message, this.fieldErrors = const {}});

  final String? code;
  final String? message;
  final Map<String, List<String>> fieldErrors;
}
