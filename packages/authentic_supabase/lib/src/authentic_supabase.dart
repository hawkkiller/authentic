import 'package:authentic/authentic.dart';
import 'package:supabase/supabase.dart';

/// An implementation of [Authentic] that uses Supabase as the backend.
class AuthenticSupabase implements Authentic {
  /// Creates a new instance of [AuthenticSupabase].
  AuthenticSupabase(this.supabaseClient);

  /// The Supabase client.
  ///
  /// It should already be initialized when passed to this class.
  final SupabaseClient supabaseClient;

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  Future<void> initialize() {
    // TODO: implement initialize
    throw UnimplementedError();
  }

  @override
  Future<void> refreshSession() {
    // TODO: implement refreshSession
    throw UnimplementedError();
  }

  @override
  // TODO: implement session
  Session? get session => throw UnimplementedError();

  @override
  // TODO: implement sessionStream
  Stream<Session> get sessionStream => throw UnimplementedError();

  @override
  Future<void> signInWithApple() {
    // TODO: implement signInWithApple
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) {
    // TODO: implement signInWithEmailAndPassword
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGoogle() {
    // TODO: implement signInWithGoogle
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    // TODO: implement signOut
    throw UnimplementedError();
  }

  @override
  Future<void> signUpWithEmailAndPassword(String email, String password) {
    // TODO: implement signUpWithEmailAndPassword
    throw UnimplementedError();
  }
}
