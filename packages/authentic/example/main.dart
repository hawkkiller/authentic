import 'dart:async';

import 'package:authentic/authentic.dart';

class AuthenticInMemory extends Authentic<Session> {
  final _sessionController = StreamController<Session>.broadcast();
  Session? _session;

  @override
  Future<void> initialize() async {}

  @override
  Session? get session => _session;

  set session(Session? value) {
    _session = value;
    _sessionController.add(_session!);
  }

  @override
  Stream<Session> get sessionStream => _sessionController.stream;

  @override
  Future<void> close() async {
    await _sessionController.close();
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    session = Session(email);
  }

  @override
  Future<void> signOut() async {
    session = null;
  }
}

class Session {
  Session(this.username);

  final String username;
}
