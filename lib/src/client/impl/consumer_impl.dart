part of dart_amqp.client;

class _ConsumerImpl implements Consumer {
  String _tag;
  final _controller = StreamController<AmqpMessage>();
  final _ChannelImpl channel;
  final _QueueImpl queue;

  String get tag => _tag;

  _ConsumerImpl(
    this.channel,
    this.queue,
    this._tag,
  );

  StreamSubscription<AmqpMessage> listen(void onData(AmqpMessage event),
          {Function onError, void onDone(), bool cancelOnError}) =>
      _controller.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  Future<Consumer> cancel({bool noWait = false}) {
    BasicCancel cancelRequest = BasicCancel()
      ..consumerTag = _tag
      ..noWait = noWait;

    Completer<Consumer> completer = Completer<Consumer>();
    channel.writeMessage(cancelRequest,
        completer: completer, futurePayload: this);
    completer.future.then((_) => _controller.close());
    return completer.future;
  }

  void onMessage(DecodedMessageImpl serverMessage) {
    // Ensure that messate contains a non-null property object
    serverMessage.properties ??= MessageProperties();

    _controller.add(_AmqpMessageImpl.fromDecodedMessage(this, serverMessage));
  }
}
