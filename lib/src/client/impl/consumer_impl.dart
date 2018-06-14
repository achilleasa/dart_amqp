part of dart_amqp.client;

class _ConsumerImpl implements Consumer {
  String _tag;
  final StreamController _controller;
  final _ChannelImpl channel;
  final _QueueImpl queue;

  String get tag => _tag;

  _ConsumerImpl(_ChannelImpl this.channel, _QueueImpl this.queue, String this._tag) : _controller = new StreamController<AmqpMessage>();

  StreamSubscription<AmqpMessage> listen(void onData(AmqpMessage event), { Function onError, void onDone(), bool cancelOnError}) => _controller.stream.listen(onData, onError : onError, onDone : onDone, cancelOnError : cancelOnError);

  Future<Consumer> cancel({bool noWait : false}) {
    BasicCancel cancelRequest = new BasicCancel()
      ..consumerTag = _tag
      ..noWait = noWait;

    Completer<Consumer> completer = new Completer<Consumer>();
    channel.writeMessage(cancelRequest, completer : completer, futurePayload : this);
    completer.future.then((_) => _controller.close());
    return completer.future;
  }

  void onMessage(DecodedMessageImpl serverMessage) {
    // Ensure that messate contains a non-null property object
    if (serverMessage.properties == null) {
      serverMessage.properties = new MessageProperties();
    }

    _controller.add(new _AmqpMessageImpl.fromDecodedMessage(this, serverMessage));
  }
}
