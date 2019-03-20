part of dart_amqp.client;

abstract class Channel {
  /// Close the channel, abort any pending operations and return a [Future<Channel>] to be completed
  /// when the channel is closed.
  ///
  /// After closing the channel any attempt to send a message over it will cause a [StateError]
  Future<Channel> close();

  /// Define a queue named [name]. Returns a [Future<Queue>] to be completed when the queue is allocated.
  ///
  /// The [passive] flag can be used to test if the queue exists. When [passive] is set to true, the
  /// returned future will fail with a [QueueNotFoundException] if the queue does not exist.
  ///
  /// The [durable] flag will enable the queue to persist across server restarts.
  ///
  /// The [exclusive] flag will mark the connection as private and accessible only by the current connection. The
  /// server will automatically delete the queue when the connection closes.
  ///
  /// The [autoDelete] flag will notify the server that the queue should be deleted when no more connections
  /// are using it.
  Future<Queue> queue(String name,
      {bool passive = false,
      bool durable = false,
      bool exclusive = false,
      bool autoDelete = false,
      bool noWait = false,
      Map<String, Object> arguments});

  /// A convenience method for allocating private queues. The client will allocate
  /// an exclusive queue with a random, server-assigned name and return a [Future<Queue>]
  /// to be completed when the server responds.
  Future<Queue> privateQueue(
      {bool noWait = false, Map<String, Object> arguments});

  /// Define an exchange named [name] of type [type] and return a [Future<Exchange>] when the exchange is allocated.
  ///
  /// The [passive] flag can be used to test if the exchange exists. When [passive] is set to true, the
  /// returned future will fail with a [ExchangeNotFoundException] if the exchange does not exist.
  ///
  /// The [durable] flag will enable the exchange to persist across server restarts.
  Future<Exchange> exchange(String name, ExchangeType type,
      {bool passive = false,
      bool durable = false,
      bool noWait = false,
      Map<String, Object> arguments});

  /// Setup the [prefetchSize] and [prefetchCount] QoS parameters.
  /// Returns a [Future<Channel>] with the affected channel once the server
  /// confirms the updated QoS settings.
  Future<Channel> qos(int prefetchSize, int prefetchCount);

  /// Acknowledge a [deliveryTag]. The [multiple] flag can be set to true
  /// to notify the server that the client ack-ed all pending messages up to [deliveryTag].
  ///
  /// Generally you should not use this method directly but rather use the
  /// methods in [AmqpMessage] to handle acks
  void ack(int deliveryTag, {bool multiple = false});

  /// Begin a transaction on the current channel. Returns a [Future<Channel>] with
  /// the affected channel.
  Future<Channel> select();

  /// Commit an open transaction on the current channel. Returns a [Future<Channel>] with
  /// the affected channel.
  ///
  /// This call will fail if [select] has not been invoked before committing.
  Future<Channel> commit();

  /// Rollback an open transaction on the current channel. Returns a [Future<Channel>] with
  /// the affected channel.
  ///
  /// This call will fail if [select] has not been invoked before rolling back.
  Future<Channel> rollback();

  /// Enable or disable the flow of messages to the client depending on [active]
  /// flag. This call should be used to notify the server that the
  /// client cannot handle the volume of incoming messages on the channel.
  ///
  /// Returns a [Future<Channel>] with the affected channel.
  Future<Channel> flow(bool active);

  /// Ask the server to re-deliver unacknowledged messages. If this [requeue] flag is false,
  /// the server will redeliver messages to the original recipient. If [requeue] is
  /// set to true, the server will attempt to requeue the message, potentially then
  /// delivering it to an alternative client.
  ///
  /// Returns a [Future<Channel>] with the affected channel.
  Future<Channel> recover(bool requeue);

  /// Register a listener for basicReturn Messages
  StreamSubscription<BasicReturnMessage> basicReturnListener(
      void onData(BasicReturnMessage message),
      {Function onError,
      void onDone(),
      bool cancelOnError});
}
