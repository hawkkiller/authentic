import 'dart:async';

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

  AuthenticSession? _session;
  final _sessionController = StreamController<AuthenticSession?>.broadcast();

  @override
  AuthenticSession? get session => _session;

  @override
  Stream<AuthenticSession?> get sessionStream => _sessionController.stream;

  @override
  Future<void> initialize() async {
    _updateSession();
  }

  @override
  Future<void> close() async {
    await _sessionController.close();
  }

  @override
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    await supabaseClient.auth.signUp(password: password, email: email);
    _updateSession();
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await supabaseClient.auth.signInWithPassword(email: email, password: password);
    _updateSession();
  }

  @override
  Future<void> refreshSession() async {
    await supabaseClient.auth.refreshSession();
    _updateSession();
  }

  @override
  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Sign in with Google is not implemented yet.');
  }

  @override
  Future<void> signInWithApple() async {
    throw UnimplementedError('Sign in with Apple is not implemented yet.');
  }

  @override
  Future<void> signOut() async {
    await supabaseClient.auth.signOut();
  }

  void _updateSession() {
    final session = supabaseClient.auth.currentSession;
    if (session == null) {
      _session = null;
    } else {
      _session = AuthenticSession(accessToken: session.accessToken);
    }

    _sessionController.add(_session);
  }
}
