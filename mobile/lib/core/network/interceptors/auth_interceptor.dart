import 'package:dio/dio.dart';

/// Attaches the bearer token to outgoing requests.
///
/// The token is pulled through [tokenProvider] rather than held here, so this
/// interceptor never becomes a second place where session state lives. The
/// auth feature owns that state; this only reads it.
///
/// Refresh-on-401 is deliberately *not* implemented yet. Doing it correctly
/// means single-flight refresh (many parallel 401s must trigger one refresh,
/// not one each) and replaying the queued requests afterwards. That belongs
/// with the session controller in Phase 2, where it can be tested against a
/// real token lifecycle.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenProvider});

  /// Returns the current access token, or `null` when signed out.
  final Future<String?> Function() tokenProvider;

  /// Requests that must go out unauthenticated. Sending a stale token to the
  /// refresh endpoint is how refresh loops start.
  static const Set<String> _publicPaths = {
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/forgot-password',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_publicPaths.any(options.path.endsWith)) {
      return handler.next(options);
    }

    final token = await tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
