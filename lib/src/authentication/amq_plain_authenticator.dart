part of dart_amqp.authentication;

class AmqPlainAuthenticator implements Authenticator {
  final String userName;
  final String password;

  /// Create a new [PlainAuthenticator] with the specified [userName] and [password]
  const AmqPlainAuthenticator(this.userName, this.password);

  /// Get the class of this authenticator
  String get saslType => "AMQPLAIN";

  /// Process the [challenge] sent by the server and return a [String] response
  String answerChallenge(String challenge) {
    // Encode as a able
    TypeEncoder encoder = TypeEncoder();
    encoder.writeFieldTable({"LOGIN": userName, "PASSWORD": password});

    // The spec defines the challenge response as a string (with its own length as a prefix). We
    // need to skip the table length from our response so the length does not get written twice
    Uint8List res = encoder.writer.joinChunks();
    return String.fromCharCodes(Uint8List.view(res.buffer, 4));
  }
}
