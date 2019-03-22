part of dart_amqp.client;

abstract class Queue {
  /// Get the queue name
  String get name;

  int get messageCount;

  int get consumerCount;

  /// Get the [Channel] where this [Queue] was declared
  Channel get channel;

  /// Delete the queue and return a [Future<Queue>] for the deleted queue.
  ///
  /// If the [ifUnsused] flag is set, the server will only delete the queue if it has no consumers. If the
  /// flag is set and the queue has any consumer left, then the server will raise an exception.
  ///
  /// If the [ifEmpty] flag is set, the server will only delete the queue if it has no messages. If the
  /// flag is set and the queue has any messages on it, the server will raise an exception.
  Future<Queue> delete(
      {bool ifUnused = false, bool IfEmpty = false, bool noWait = false});

  /// Purge any queued messages that are not awaiting acknowledgment.
  ///
  /// Returns a [Future<Queue>] for the purged queue.
  Future<Queue> purge({bool noWait = false});

  /// Bind this queue to [exchange] using [routingKey] and return a [Future<Queue>] to the bound queue.
  ///
  /// The [routingKey] parameter cannot be empty or null unless [exchange] is of type [ExchangeType.FANOUT] or [ExchangeType.HEADERS].
  /// For any other [exchange] type, passing an empty or null [routingKey] will cause an [ArgumentError]
  /// to be thrown.
  Future<Queue> bind(Exchange exchange, String routingKey,
      {bool noWait, Map<String, Object> arguments});

  /// Unbind this queue from [exchange] with [routingKey] and return a [Future<Queue>] to the unbound queue.
  ///
  /// The [routingKey] parameter cannot be empty or null unless [exchange] is of type [ExchangeType.FANOUT] or [ExchangeType.HEADERS].
  /// For any other [exchange] type, passing an empty or null [routingKey] will cause an [ArgumentError]
  /// to be thrown.
  Future<Queue> unbind(Exchange exchange, String routingKey,
      {bool noWait, Map<String, Object> arguments});

  /// Publish [message] to the queue. [message] should be either a [Uint8List], a [String], a [Map] or [Iterable].
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
  void publish(Object message,
      {MessageProperties properties,
      bool mandatory = false,
      bool immediate = false});

  /// Create a consumer for processing queued messages and return a [Future<Consumer>] to the created
  /// consumer.
  ///
  /// You may specify a [consumerTag] to label this consumer. If left unspecified, the server will assign a
  /// random tag to this consumer. Consumer tags are local to the current channel.
  ///
  /// The [noAck] flag will notify the server whether the consumer is expected to acknowledge incoming
  /// messages or not.
  ///
  /// If the [exclusive] flag is set then only this consumer has access to the queue. If the flag is set
  /// and the queue already has attached consumers, then the server will raise an error.
  Future<Consumer> consume(
      {String consumerTag,
      bool noLocal = false,
      bool noAck = true,
      bool exclusive = false,
      bool noWait = false,
      Map<String, Object> arguments});
}
