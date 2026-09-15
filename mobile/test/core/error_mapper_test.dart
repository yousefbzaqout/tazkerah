import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/core/errors/error_mapper.dart';
import 'package:tazkerah/core/errors/failure.dart';

/// Builds a [DioException] carrying a response, for the status-code cases.
DioException _responseError(int statusCode, {Object? body, Headers? headers}) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
      headers: headers,
    ),
  );
}

void main() {
  group('ErrorMapper transport failures', () {
    test('maps every timeout variant to TimeoutFailure', () {
      const timeoutTypes = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ];

      for (final type in timeoutTypes) {
        final failure = ErrorMapper.mapDioException(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: type,
          ),
        );
        expect(failure, isA<TimeoutFailure>(), reason: 'for $type');
      }
    });

    test('maps connection errors to NetworkFailure', () {
      final failure = ErrorMapper.mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('maps cancellation to CancelledFailure', () {
      final failure = ErrorMapper.mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.cancel,
        ),
      );
      expect(failure, isA<CancelledFailure>());
    });

    test(
      'flags a bad certificate distinctly, since it may be a failed pin',
      () {
        final failure = ErrorMapper.mapDioException(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.badCertificate,
          ),
        );
        expect(failure, isA<NetworkFailure>());
        expect(failure.code, 'BAD_CERTIFICATE');
      },
    );
  });

  group('ErrorMapper status codes', () {
    test('401 becomes UnauthorizedFailure', () {
      expect(
        ErrorMapper.mapDioException(_responseError(401)),
        isA<UnauthorizedFailure>(),
      );
    });

    test('403 becomes ForbiddenFailure', () {
      expect(
        ErrorMapper.mapDioException(_responseError(403)),
        isA<ForbiddenFailure>(),
      );
    });

    test('404 becomes NotFoundFailure', () {
      expect(
        ErrorMapper.mapDioException(_responseError(404)),
        isA<NotFoundFailure>(),
      );
    });

    test('409 becomes ConflictFailure — the taken-seat case', () {
      expect(
        ErrorMapper.mapDioException(_responseError(409)),
        isA<ConflictFailure>(),
      );
    });

    test('every 5xx becomes ServerFailure carrying its status', () {
      for (final status in [500, 502, 503, 504]) {
        final failure = ErrorMapper.mapDioException(_responseError(status));
        expect(failure, isA<ServerFailure>(), reason: 'for $status');
        expect((failure as ServerFailure).statusCode, status);
      }
    });
  });

  group('ErrorMapper envelope parsing', () {
    test('extracts the backend error code so features can branch on it', () {
      final failure = ErrorMapper.mapDioException(
        _responseError(
          409,
          body: {
            'error': {
              'code': 'SEAT_UNAVAILABLE',
              'message': 'Seat already held',
            },
          },
        ),
      );

      expect(failure, isA<ConflictFailure>());
      expect(failure.code, 'SEAT_UNAVAILABLE');
      expect(failure.debugMessage, 'Seat already held');
    });

    test('collects per-field errors from a 422', () {
      final failure = ErrorMapper.mapDioException(
        _responseError(
          422,
          body: {
            'error': {
              'code': 'VALIDATION_FAILED',
              'details': {
                'email': ['Must be a valid address'],
                'password': ['Too short', 'Needs a digit'],
              },
            },
          },
        ),
      );

      expect(failure, isA<ValidationFailure>());
      final fieldErrors = (failure as ValidationFailure).fieldErrors;
      expect(fieldErrors['email'], ['Must be a valid address']);
      expect(fieldErrors['password'], hasLength(2));
    });

    test('reads Retry-After off a 429', () {
      final options = RequestOptions(path: '/test');
      final failure = ErrorMapper.mapDioException(
        _responseError(
          429,
          headers: Headers.fromMap({
            'retry-after': ['30'],
          }),
        ),
      );

      expect(failure, isA<RateLimitFailure>());
      expect(
        (failure as RateLimitFailure).retryAfter,
        const Duration(seconds: 30),
      );
      expect(options.path, '/test');
    });

    test('survives a malformed body rather than throwing over it', () {
      // A proxy or gateway may return HTML where JSON was expected. Losing the
      // real error behind a parsing crash would be worse than a generic one.
      for (final body in <Object?>[
        null,
        'a plain string',
        {'error': 'not an object'},
        {'error': <String, Object?>{}},
        {'unexpected': 'shape'},
        <Object?>[],
      ]) {
        expect(
          () => ErrorMapper.mapDioException(_responseError(500, body: body)),
          returnsNormally,
          reason: 'for body: $body',
        );
      }
    });
  });
}
