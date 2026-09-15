/// Whether the app has a usable session.
///
/// Deliberately three states, not a bool. [unknown] is the window while
/// secure storage is being read at launch: treating it as signed-out would
/// flash the login screen at a user who is already authenticated, and
/// treating it as signed-in would flash the home tabs at one who is not.
/// The router holds on the splash screen until this resolves.
enum AuthStatus {
  /// Startup check has not finished.
  unknown,

  /// A refresh token is present.
  authenticated,

  /// No session, or it was cleared.
  unauthenticated,
}
