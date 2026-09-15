import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import '../utils/clock.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/clock_sync_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// The app's HTTP entry point.
///
/// Wraps Dio so that no layer above the data sources needs to import it, and
/// so every call comes back as either a decoded body or a [Failure] — callers
/// never handle [DioException].
///
/// Repositories own instances of this; presentation must not. A widget that
/// reaches for [ApiClient] is a widget doing data-layer work.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required AppClock clock,
    required Future<String?> Function() tokenProvider,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      // Let every status through to the error mapper, which knows how to turn
      // a code into a Failure. Dio's own threshold would throw first and lose
      // the response envelope.
      validateStatus: (status) => status != null && status < 400,
    );

    _dio.interceptors.addAll([
      AuthInterceptor(tokenProvider: tokenProvider),
      ClockSyncInterceptor(clock: clock),
      if (config.enableNetworkLogging) LoggingInterceptor(),
    ]);
  }

  final Dio _dio;

  /// Escape hatch for the streaming cases Dio handles better directly — SSE
  /// for the AI concierge, and file downloads for Wallet passes.
  ///
  /// Data-layer use only.
  Dio get raw => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Runs [request] and normalises everything it can throw into a [Failure].
  ///
  /// This is the boundary: past this point Dio's exception types do not exist.
  Future<T> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw const UnknownFailure(debugMessage: 'Response body was null');
      }
      return data;
    } on DioException catch (e) {
      throw ErrorMapper.mapDioException(e);
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(debugMessage: e.toString());
    }
  }
}
