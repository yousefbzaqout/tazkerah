/// Every key used in secure storage, in one place.
///
/// Centralised so two features cannot silently pick the same string, and so a
/// reviewer can audit what the app persists by reading a single file.
///
/// Note what is *absent* and must stay absent:
///
/// - the access token — it lives in memory only, for its 15-minute life;
/// - the event signing private key — server-side only, in an HSM/KMS. A copy
///   on any device would let that device forge tickets;
/// - payment card data, in any form, mock included;
/// - passwords in plaintext.
abstract final class StorageKeys {
  /// Long-lived refresh token. Rotated on every use.
  static const String refreshToken = 'auth.refresh_token';

  /// Server-issued identifier for this device's registered public key.
  static const String deviceId = 'device.id';

  /// PKCS#8 private key for ticket presentation proofs (ES256).
  ///
  /// Generated on-device and never transmitted. The public half alone goes to
  /// the backend. Wiped on sign-out.
  static const String devicePrivateKey = 'device.private_key';

  /// Encryption key for the local ticket database.
  ///
  /// The database holds the records; this holds the key that opens it.
  static const String databaseKey = 'db.encryption_key';

  /// Signed offset between server time and this device's clock, in
  /// milliseconds. Rotating codes are generated against corrected time so that
  /// changing the device clock cannot shift the rotation window.
  static const String clockOffsetMillis = 'clock.offset_millis';

  /// When [clockOffsetMillis] was last refreshed, as an ISO-8601 UTC string.
  /// A stale offset warrants a warning in the ticket UI.
  static const String clockSyncedAt = 'clock.synced_at';

  /// Last-known-good copy of the first page of the discovery feed.
  ///
  /// Not a secret — event listings are public. It lives here because this is
  /// the storage abstraction the app has, and because a key registry is only
  /// an audit tool if it is complete. Cleared on sign-out with everything
  /// else.
  static const String cachedEventsFeed = 'events.feed.v1';

  /// Set on first successful run. Its absence after install means leftover
  /// Keychain entries from a previous install must be cleared.
  static const String installSentinel = 'app.install_sentinel';
}
