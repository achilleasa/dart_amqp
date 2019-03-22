part of dart_amqp.client;

abstract class AmqpMessage {
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

  /// Get the name of the exchange where this message arrived from. The
  /// method will return null if the message did not arrive through an
  /// exchange (e.g. posted directly to a queue).
  String get exchangeName;

  /// Get the routing key for this message. The
  /// method will return null if the message did not arrive through an
  /// exchange (e.g. posted directly to a queue).
  String get routingKey;

  /// Get the [properties] that were included with the message metadata
  MessageProperties get properties;

  /// Acknowledge this message.
  void ack();

  /// Reply to the sender of this message with a new [message]. [message] should be either a [Uint8List], a [String], a [Map] or [Iterable].
  /// If [message] is [Map] or [Iterable] it will be encoded as JSON and the appropriate message properties
  /// (content-type and content-encoding) will be set on the outgoing message. Any other [message] value will
  /// trigger an [ArgumentError].
  ///
  /// You may specify additional message properties by setting the [properties] named parameter.
  ///
  /// If the [mandatory] flag is set, the server will return un-routable messages back to the client. Otherwise
  /// the server will drop un-routable messages.
  ///
  /// if the [immediate] flag is set, the server will immediately return undeliverable messages to the client
  /// if it cannot route them. If the flag is set to false, the server will queue the message even though
  /// there is no guarantee that it will ever be consumed.
  void reply(Object responseMessage,
      {MessageProperties properties,
      bool mandatory = false,
      bool immediate = false});

  /// Reject this message because the client cannot process it.
  ///
  /// If the [requeue] flag is set, then the server will attempt to forward the rejected
  /// message to another client.
  void reject(bool requeue);
}
