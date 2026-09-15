import 'dart:convert';

import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../domain/event_summary.dart';
import '../domain/events_repository.dart';

/// Last-known-good copy of the first page of the feed.
///
/// This is what makes the design's offline state honest. Without it, "Offline
/// — showing cached events" would be a banner over an empty list; with it, the
/// user who opens the app in a basement sees the events they saw this morning,
/// correctly labelled as stale.
///
/// Only the **first page** is kept, deliberately. The value of the cache is
/// having something to show immediately; paging deeper is an online activity,
/// and persisting an unbounded feed would grow without limit for a benefit
/// nobody asked for.
///
/// It stores through [SecureStorage] because that is the storage abstraction
/// this app has — not because event listings are secret. They are public
/// information. The honest reason is that a second storage dependency would
/// need its own justification, its own test double and its own platform
/// channel; reusing the one that already exists costs nothing here, since the
/// payload is small and written rarely.
class EventsCache {
  const EventsCache(this._storage);

  final SecureStorage _storage;

  /// Storage key, from the central registry. Versioned in the name: if the
  /// shape below changes, the old value is simply never read again rather
  /// than mis-parsed.
  static const String _key = StorageKeys.cachedEventsFeed;

  /// Beyond this age the cache is discarded rather than shown.
  ///
  /// A day-old feed is useful; a month-old one is misinformation — it will
  /// advertise events that have already happened and prices that have moved.
  /// The banner says "cached", not "wrong".
  static const Duration maxAge = Duration(hours: 24);

  /// Replaces the cached page. Failures are swallowed: a cache that cannot be
  /// written is a degraded experience later, not an error now, and surfacing
  /// it would turn a successful fetch into a visible failure.
  Future<void> save(List<EventSummary> events, {required DateTime at}) async {
    try {
      await _storage.write(
        _key,
        jsonEncode({
          'cached_at': at.toUtc().toIso8601String(),
          'events': events.map(_encode).toList(),
        }),
      );
    } catch (_) {
      // Intentionally ignored — see above.
    }
  }

  /// Reads the cached page, or null when there is none, it cannot be parsed,
  /// or it is older than [maxAge].
  ///
  /// Parse failures return null rather than throwing: the cache is an
  /// optimisation, and a corrupt one must not be able to take down a screen
  /// that could otherwise have shown an error state.
  Future<EventPage?> read() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedAt = DateTime.tryParse(decoded['cached_at'] as String? ?? '');
      if (cachedAt == null) return null;
      if (DateTime.now().toUtc().difference(cachedAt) > maxAge) return null;

      final rows = decoded['events'];
      if (rows is! List) return null;

      final events = <EventSummary>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final event = _decode(row);
        // One unreadable row must not discard the rest of the page.
        if (event != null) events.add(event);
      }

      if (events.isEmpty) return null;
      return EventPage(events: events, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  /// Drops the cached page. Called on sign-out — the next user of this device
  /// should not inherit the previous one's feed.
  Future<void> clear() async {
    try {
      await _storage.delete(_key);
    } catch (_) {
      // Ignored for the same reason as in `save`.
    }
  }

  static Map<String, dynamic> _encode(EventSummary e) => {
    'id': e.id,
    'title': e.title,
    'venue': e.venue,
    'city': e.city,
    'starts_at': e.startsAt.toUtc().toIso8601String(),
    'ends_at': e.endsAt?.toUtc().toIso8601String(),
    'price_from': e.priceFrom,
    'currency': e.currency,
    'image_url': e.imageUrl,
    'sold_out': e.soldOut,
  };

  static EventSummary? _decode(Map<String, dynamic> row) {
    final id = row['id'];
    final title = row['title'];
    final startsAt = DateTime.tryParse(row['starts_at'] as String? ?? '');
    final priceFrom = row['price_from'];

    // These four have no sensible default. A row missing any of them is not a
    // renderable card, so it is dropped rather than patched with a guess.
    if (id is! String || title is! String || startsAt == null) return null;
    if (priceFrom is! num) return null;

    final endsAtRaw = row['ends_at'];
    return EventSummary(
      id: id,
      title: title,
      venue: row['venue'] as String? ?? '',
      city: row['city'] as String? ?? '',
      startsAt: startsAt,
      endsAt: endsAtRaw is String ? DateTime.tryParse(endsAtRaw) : null,
      priceFrom: priceFrom,
      currency: row['currency'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      soldOut: row['sold_out'] as bool? ?? false,
    );
  }
}
