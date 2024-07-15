import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

// Slow implementation of fib
int fib(int n) {
  if (n == 0) {
    return 0;
  } else if (n == 1) {
    return 1;
  }
  return fib(n - 1) + fib(n - 2);
}

void main(List<String> args) async {
  Client client = Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) async {
    await client.close();
    exit(0);
  });

  Channel channel = await client.channel();
  channel = await channel.qos(0, 1);
  Queue queue = await channel.queue("rpc_queue");
  Consumer consumer = await queue.consume();
  print(" [x] Awaiting RPC request");
  consumer.listen((message) {
    int n = message.payloadAsJson["n"];
    print(" [.] fib($n)");
    message.reply(fib(n).toString());
  });
}
