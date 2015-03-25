import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

// Slow implementation of fib
int fib(int n) {
  if (n == 0) {
    return 0;
  } else if (n == 1) {
    return 1;
  }
  return fib(n - 1) + fib(n - 2);
}

void main(List<String> args) {

  Client client = new Client();

  // Setup a signal hundler to cleanly exit if CTRL+C is pressed
  ProcessSignal.SIGINT.watch().listen((_) {
    client.close().then((_) {
      exit(0);
    });
  });

  client
  .channel()
  .then((Channel channel) => channel.qos(0, 1))
  .then((Channel channel) => channel.queue("rpc_queue"))
  .then((Queue queue) => queue.consume())
  .then((Consumer consumer) {
    print(" [x] Awaiting RPC request");
    consumer.listen((AmqpMessage message) {
      int n = message.payloadAsJson["n"];
      print(" [.] fib(${n})");
      message.reply(fib(n).toString());
    });
  });
}