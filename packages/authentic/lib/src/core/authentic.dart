/// A class that handles authentication operations for an application.
///
/// The generic type [Session] represents the user session object.
abstract class Authentic<Session extends Object> {
  /// The current active session, if any.
  Session? get session;

  /// Stream of session changes.
  ///
  /// Emits when a user signs in, signs out, or the session is refreshed.
  Stream<Session> get sessionStream;

  /// Initializes the authentication service.
  ///
  /// This should be called during the app startup before performing any authentication operations.
  Future<void> initialize();

  /// Refreshes the current session.
  Future<void> refreshSession() {
    throw UnimplementedError('refreshSession() is not implemented.');
  }

  /// Signs in a user with their email and password.
  Future<void> signInWithEmailAndPassword(String email, String password) {
    throw UnimplementedError('signInWithEmailAndPassword() is not implemented.');
  }

  /// Creates a new account using email and password.
  Future<void> signUpWithEmailAndPassword(String email, String password) {
    throw UnimplementedError('signUpWithEmailAndPassword() is not implemented.');
  }

  /// Initiates the sign-in process using Apple authentication.
  Future<void> signInWithApple() {
    throw UnimplementedError('signInWithApple() is not implemented.');
  }

  /// Initiates the sign-in process using Google authentication.
  Future<void> signInWithGoogle() {
    throw UnimplementedError('signInWithGoogle() is not implemented.');
  }

  /// Signs out the current user and clears the session.
  Future<void> signOut() {
    throw UnimplementedError('signOut() is not implemented.');
  }

  /// Closes the authentication service.
  ///
  /// In real-world applications, this method should never be called
  /// as the authentication service should be kept alive throughout the app lifecycle.
  Future<void> close();
}
