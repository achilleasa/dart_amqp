part of dart_amqp.client;

abstract class Exchange {
  /// Get the name of the exchange
  String get name;

  /// Get the type of the exchange
  ExchangeType get type;

  /// Get the [Channel] where this exchange was declared
  Channel get channel;

  /// Delete the exchange and return a [Future<Exchange>] to the deleted exchange.
  ///
  /// If the [ifUnsused] flag is set, the server will only delete the exchange if it has no queue-bindings. If the
  /// flag is set and the exchange has any queue bindings left, then the server will raise an exception.
  Future<Exchange> delete({bool ifUnused = false, bool noWait = false});

  /// Publish [message] to the exchange. [message] should be either a [Uint8List], a [String], a [Map] or [Iterable].
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
  void publish(Object message, String routingKey,
      {MessageProperties properties,
      bool mandatory = false,
      bool immediate = false});

  /// Allocate a private [Queue], bind it to this exchange using the supplied [routingKeys],
  /// allocate a [Consumer] and return a [Future<Consumer>].
  ///
  /// You may specify a [consumerTag] to label this consumer. If left unspecified, the server will assign a
  /// random tag to this consumer. Consumer tags are local to the current channel.
  ///
  /// The [noAck] flag will notify the server whether the consumer is expected to acknowledge incoming
  /// messages or not.
  Future<Consumer> bindPrivateQueueConsumer(List<String> routingKeys,
      {String consumerTag, bool noAck = true});

  /// Allocate a named [Queue], bind it to this exchange using the supplied [routingKeys],
  /// allocate a [Consumer] and return a [Future<Consumer>].
  ///
  /// You may specify a queue name and a [consumerTag] to label this consumer. If left unspecified,
  /// the server will assign a random tag to this consumer. Consumer tags are local to the current channel.
  ///
  /// The [noAck] flag will notify the server whether the consumer is expected to acknowledge incoming
  /// messages or not.
  Future<Consumer> bindQueueConsumer(String queueName, List<String> routingKeys,
      {String consumerTag, bool noAck = true});
}
