import 'dart:async';

import 'package:authentic/authentic.dart';

class AuthenticInMemory extends Authentic {
  final _sessionController = StreamController<Session>.broadcast();
  Session? _session;

  @override
  Future<void> close() async {
    await _sessionController.close();
  }

  @override
  Future<void> initialize() {
    return Future.value();
  }

  @override
  Session? get session => _session;

  @override
  Stream<Session> get sessionStream => _sessionController.stream;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _session = Session(accessToken: 'access_token');
  }
}
