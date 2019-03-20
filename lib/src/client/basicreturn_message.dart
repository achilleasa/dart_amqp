part of dart_amqp.client;

abstract class BasicReturnMessage {
  /// Get the payload as a [Uint8List]
  Uint8List get payload;

  /// Get the payload as a [String]. This method will pass
  /// the message [payload] through UTF8.decode and return
  /// the decoded string.
  String get payloadAsString;

  /// Get the payload as a [Map]. This method will pass the
  /// message [payload] through a JSON decoded and return the
  /// decoded JSON data as a [Map].
  Map get payloadAsJson;

  /// Get the [properties] that were included with the message metadata
  MessageProperties get properties;

  /// The reply code for the return message
  int get replyCode;

  /// The localised reply text. This text can be logged as an aid to resolving issues.

  String get replyText;

  /// Get the name of the exchange where returned message was sent to.
  String get exchangeName;

  /// Get the routing key for the returned message message. The
  /// method will return null if the message did not arrive through an
  /// exchange (e.g. posted directly to a queue).
  String get routingKey;
}
