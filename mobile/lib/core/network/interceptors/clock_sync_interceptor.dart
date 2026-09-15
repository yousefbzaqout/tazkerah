import 'package:dio/dio.dart';

import '../../utils/clock.dart';

/// Harvests the `Date` header from every response to keep the app's notion of
/// server time current.
///
/// This is a security control, not a convenience. Rotating ticket codes are
/// generated against server-corrected time; if the app trusted the device
/// clock, changing it in Settings would let a user shift the rotation window.
/// Piggybacking on ordinary traffic means the offset stays fresh without a
/// dedicated time endpoint or extra requests.
///
/// The offset is a hint, never an authority. The scanner at the gate holds the
/// trusted clock and rejects proofs outside its own tolerance window, so a
/// wrong device clock produces a legible failure rather than a bypass.
class ClockSyncInterceptor extends Interceptor {
  ClockSyncInterceptor({required this.clock});

  final AppClock clock;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _syncFrom(response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // An error response still carries a trustworthy Date header, and a device
    // that is failing requests is exactly when the offset matters most.
    _syncFrom(err.response?.headers);
    handler.next(err);
  }

  void _syncFrom(Headers? headers) {
    final raw = headers?.value('date');
    if (raw == null) return;

    final serverTime = _parseHttpDate(raw);
    if (serverTime == null) return;

    clock.syncTo(serverTime);
  }

  /// Parses an RFC 7231 IMF-fixdate, the format required for `Date`.
  ///
  /// Returns `null` rather than throwing: a malformed header from a proxy must
  /// not break the request it arrived on.
  static DateTime? _parseHttpDate(String value) {
    try {
      return HttpDateParser.parse(value);
    } catch (_) {
      return null;
    }
  }
}

/// Minimal IMF-fixdate parser.
///
/// `dart:io`'s `HttpDate.parse` exists but pulls in `dart:io`, which is
/// unavailable on web and awkward in tests. The format is fixed and narrow, so
/// parsing it here keeps this layer platform-neutral.
abstract final class HttpDateParser {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Parses `Sun, 06 Nov 1994 08:49:37 GMT`.
  ///
  /// Throws [FormatException] when [value] does not match.
  static DateTime parse(String value) {
    // Example: "Sun, 06 Nov 1994 08:49:37 GMT"
    final match = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value.trim());

    if (match == null) {
      throw FormatException('Not an IMF-fixdate', value);
    }

    final monthIndex = _months.indexOf(match.group(2)!);
    if (monthIndex < 0) {
      throw FormatException('Unknown month', value);
    }

    return DateTime.utc(
      int.parse(match.group(3)!),
      monthIndex + 1,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
