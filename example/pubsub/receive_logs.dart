import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main() async {
  Client client = Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) async {
    await client.close();
    exit(0);
  });

  Channel channel = await client.channel();
  Exchange exchange = await channel.exchange("logs", ExchangeType.FANOUT);
  Consumer consumer = await exchange.bindPrivateQueueConsumer(null);
  print(
      " [*] Waiting for logs on private queue ${consumer.queue.name}. To exit, press CTRL+C");
  consumer.listen((message) {
    print(" [x] ${message.payloadAsString}");
  });
}
