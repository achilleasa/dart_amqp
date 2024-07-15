import "dart:async";
import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

class FibonacciRpcClient {
  int _nextCorrelationId = 1;
  final Completer connected = Completer();
  final Client client;
  final Map<String, Completer> _pendingOperations = <String, Completer>{};
  late Queue _serverQueue;
  late String _replyQueueName;

  FibonacciRpcClient() : client = Client() {
    _init();
  }

  Future<void> _init() async {
    Channel channel = await client.channel();
    _serverQueue = await channel.queue("rpc_queue");
    // Allocate a private queue for server responses
    Queue queue = await _serverQueue.channel.privateQueue();
    Consumer consumer = await queue.consume();
    _replyQueueName = consumer.queue.name;
    consumer.listen(handleResponse);
    connected.complete();
  }

  void handleResponse(AmqpMessage message) {
    // Ignore if the correlation id is unknown
    if (!_pendingOperations.containsKey(message.properties?.corellationId)) {
      return;
    }

    _pendingOperations
        .remove(message.properties?.corellationId)!
        .complete(int.parse(message.payloadAsString));
  }

  Future<int> call(int n) async {
    // Make sure we are connected before sending the request
    await connected.future;

    String uuid = "${_nextCorrelationId++}";
    Completer<int> completer = Completer<int>();

    MessageProperties properties = MessageProperties()
      ..replyTo = _replyQueueName
      ..corellationId = uuid;

    _pendingOperations[uuid] = completer;

    _serverQueue.publish({"n": n}, properties: properties);

    return completer.future;
  }

  Future close() {
    // Kill any pending responses
    _pendingOperations.forEach((_, Completer completer) =>
        completer.completeError("RPC client shutting down"));
    _pendingOperations.clear();

    return client.close();
  }
}

main(List<String> args) async {
  FibonacciRpcClient client = FibonacciRpcClient();

  num n = args.isEmpty ? 30 : num.parse(args[0]);

  // Make 10 parallel calls and get fib(1) to fib(10)
  int res = await client.call(n.toInt());
  print(" [x] fib($n) = $res");
  await client.close();
  exit(0);
}
