/// A session object that holds authentication information.
/// 
/// This model should contain the data that is needed by client
/// when user is authenticated.
/// 
/// For example, in a JWT-based authentication system, this could
/// contain the access token, to make authenticated requests to the server.
class Session {
  /// Creates a new session.
  Session({required this.accessToken});

  /// The access token.
  final String accessToken;
}
