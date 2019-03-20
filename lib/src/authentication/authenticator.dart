part of dart_amqp.authentication;

abstract class Authenticator {
  /// Get the SASL type of this authenticator
  String get saslType;

  /// Process the [challenge] sent by the server and return a [String] response
  String answerChallenge(String challenge);
}
