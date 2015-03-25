part of dart_amqp.client;

abstract class Consumer {

  String get tag;

  Channel get channel;

  Queue get queue;

  StreamSubscription<AmqpMessage> listen(void onData(AmqpMessage event), { Function onError, void onDone(), bool cancelOnError});

  Future<Consumer> cancel({bool noWait : false});
}
