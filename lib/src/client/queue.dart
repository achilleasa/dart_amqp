part of dart_amqp.client;

abstract class Queue {

  String get name;

  int get messageCount;

  int get consumerCount;

  Channel get channel;

  Future<Queue> delete({bool ifUnused : false, bool IfEmpty : false, bool noWait : false});

  Future<Queue> purge({bool noWait : false});

  Future<Queue> bind(Exchange exchange, String routingKey, {bool noWait, Map<String, Object> arguments});

  Future<Queue> unbind(Exchange exchange, String routingKey, {bool noWait, Map<String, Object> arguments});

  void publish(Object message, { MessageProperties properties, bool mandatory : false, bool immediate : false});

  Future<Consumer> consume({String consumerTag, bool noLocal : false, bool noAck: true, bool exclusive : false, bool noWait : false, Map<String, Object> arguments});
}
