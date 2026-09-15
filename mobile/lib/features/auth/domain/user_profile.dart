/// The signed-in user's own account.
///
/// Deliberately small. This app is a ticket wallet, not a social product: it
/// needs enough to address the user and to let a gate steward match a pass to
/// a person, and nothing beyond that. Every field here is one the backend
/// already holds because sign-in or a purchase required it.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.identifier,
    this.email,
    this.phone,
    this.memberSince,
    this.deviceId,
  });

  final String id;

  /// The name printed on passes, so a steward can check it against ID.
  final String displayName;

  /// What was used to sign in — an email or a phone number. Shown so the user
  /// can see which account they are in, which matters on a shared device.
  final String identifier;

  final String? email;
  final String? phone;

  final DateTime? memberSince;

  /// The device this account's passes are bound to: `#TZ-8841-A`.
  ///
  /// Surfaced because binding is the anti-sharing property of the whole
  /// ticket design. A user who cannot see which device holds their passes
  /// cannot reason about why a transfer or a new phone loses them.
  final String? deviceId;

  /// Initials for the avatar, from the display name.
  ///
  /// Takes the first letter of the first and last words. Grapheme-unaware
  /// substring would split an emoji or a combining mark, so this works on
  /// whole characters via [runes].
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';

    String firstRune(String word) => String.fromCharCode(word.runes.first);
    if (parts.length == 1) return firstRune(parts.first).toUpperCase();
    return (firstRune(parts.first) + firstRune(parts.last)).toUpperCase();
  }
}
