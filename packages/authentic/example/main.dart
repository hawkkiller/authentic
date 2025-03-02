import 'dart:async';

import 'package:authentic/authentic.dart';

class AuthenticInMemory extends Authentic {
  final _sessionController = StreamController<AuthenticSession>.broadcast();
  AuthenticSession? _session;

  @override
  Future<void> close() async {
    await _sessionController.close();
  }

  @override
  Future<void> initialize() {
    return Future.value();
  }

  @override
  AuthenticSession? get session => _session;

  @override
  Stream<AuthenticSession> get sessionStream => _sessionController.stream;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _session = AuthenticSession(accessToken: 'access_token');
  }
}
