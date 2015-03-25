part of dart_ampq.authentication;

class PlainAuthenticator implements Authenticator {

  final String userName;
  final String password;

  /**
   * Create a new [PlainAuthenticator] with the specified [userName] and [password]
   */
  const PlainAuthenticator(String this.userName, String this.password);

  /**
   * Get the class of this authenticator
   */
  String get saslType => "PLAIN";

  /**
   * Process the [challenge] sent by the server and return a [String] response
   */
  String answerChallenge(String challenge) {
    StringBuffer sb = new StringBuffer()
      ..writeCharCode(0)
      ..write(userName)
      ..writeCharCode(0)
      ..write(password);

    return sb.toString();
  }
}