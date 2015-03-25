part of dart_amqp.client;

abstract class Channel {

  /**
   * Close the channel and return a [Future] to be completed when the channel is closed.
   *
   * After closing the channel any attempt to send a message over it will cause a [StateError]
   */
  Future<Channel> close();

  Future<Queue> queue(String name, {bool passive : false, bool durable : false, bool exclusive : false, bool autoDelete : false, bool noWait : false, Map<String, Object> arguments });

  Future<Queue> privateQueue({bool noWait : false, Map<String, Object> arguments });

  Future<Exchange> exchange(String name, ExchangeType type, {bool passive : false, bool durable : false, bool noWait : false, Map<String, Object> arguments });

  Future<Channel> qos(int prefetchSize, int prefetchCount);

  void ack(int deliveryTag, {bool multiple : false});

  Future<Channel> select();

  Future<Channel> commit();

  Future<Channel> rollback();

  Future<Channel> flow(bool active);

  Future<Channel> recover(bool requeue);
}
