part of dart_amqp.client;

class _ConsumerImpl implements Consumer {
  // https://github.com/dart-lang/linter/issues/2697
  // ignore: prefer_final_fields
  String _tag;
  final _controller = StreamController<AmqpMessage>();
  @override
  final _ChannelImpl channel;
  @override
  final _QueueImpl queue;

  @override
  String get tag => _tag;

  _ConsumerImpl(
    this.channel,
    this.queue,
    this._tag,
  );

  @override
  StreamSubscription<AmqpMessage> listen(
          void Function(AmqpMessage event) onData,
          {Function? onError,
          void Function()? onDone,
          bool cancelOnError = false}) =>
      _controller.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<Consumer> cancel({bool noWait = false}) {
    BasicCancel cancelRequest = BasicCancel()
      ..consumerTag = _tag
      ..noWait = noWait;

    Completer<Consumer> completer = Completer<Consumer>();
    channel.writeMessage(cancelRequest,
        completer: completer, futurePayload: this, noWait: noWait);
    completer.future.then((_) => close());
    return completer.future;
  }

  void onMessage(DecodedMessageImpl serverMessage) {
    // Ignore message if the stream is closed
    if (_controller.isClosed) {
      return;
    }

    // Ensure that messate contains a non-null property object
    serverMessage.properties ??= MessageProperties();
    _controller.add(_AmqpMessageImpl.fromDecodedMessage(this, serverMessage));
  }

  void close() {
    _controller.close();
  }
}
