part of dart_amqp.client;

abstract class Exchange {

  String get name;

  ExchangeType get type;

  Channel get channel;

  Future<Exchange> delete({bool ifUnused : false, bool noWait : false});

  void publish(Object message, String routingKey, { MessageProperties properties, bool mandatory : false, bool immediate : false});

  Future<Consumer> bindPrivateQueueConsumer(List<String> routingKeys, {String consumerTag, bool noLocal : false, bool noAck: true, bool exclusive : false, bool noWait : false, Map<String, Object> arguments});
}
