import "dart:io";
import "dart:async";
import "package:dart_amqp/dart_amqp.dart";

class FibonacciRpcClient {
  int _nextCorrelationId = 1;
  final Completer connected = new Completer();
  final Client client;
  final Map<String, Completer> _pendingOperations = new Map<String, Completer>();
  Queue _serverQueue;
  String _replyQueueName;

  FibonacciRpcClient() : client = new Client() {
    client
    .channel()
    .then((Channel channel) => channel.queue("rpc_queue"))
    .then((Queue rpcQueue) {
      _serverQueue = rpcQueue;

      // Allocate a private queue for server responses
      return rpcQueue.channel.privateQueue();
    })
    .then((Queue queue) => queue.consume())
    .then((Consumer consumer) {
      _replyQueueName = consumer.queue.name;
      consumer.listen(handleResponse);
      connected.complete();
    });
  }

  void handleResponse(AmqpMessage message) {
    // Ignore if the correlation id is unknown
    if (!_pendingOperations.containsKey(message.properties.corellationId)) {
      return;
    }

    _pendingOperations
    .remove(message.properties.corellationId)
    .complete(int.parse(message.payloadAsString));
  }

  Future<int> call(int n) {
    // Make sure we are connected before sending the request
    return connected.future
    .then((_) {
      String uuid = "${_nextCorrelationId++}";
      Completer<int> completer = new Completer<int>();

      MessageProperties properties = new MessageProperties()
        ..replyTo = _replyQueueName
        ..corellationId = uuid;

      _pendingOperations[ uuid ] = completer;

      _serverQueue.publish({"n" : n}, properties : properties);

      return completer.future;
    });
  }

  Future close() {
    // Kill any pending responses
    _pendingOperations.forEach((_, Completer completer) => completer.completeError("RPC client shutting down"));
    _pendingOperations.clear();

    return client.close();
  }
}

main() {
  FibonacciRpcClient client = new FibonacciRpcClient();

  // Make 10 parallel calls and get fib(1) to fib(10)
  Future
  .wait(new Iterable.generate(10, (int index) => client.call(index + 1)))
  .then((List<int> callValues) {
    for (int index = 0; index < 10; index++) {
      print(" [x] fib(${index + 1}) = ${callValues[index]}");
    }
  })
  .then((_) => client.close())
  .then((_) => exit(0));
}