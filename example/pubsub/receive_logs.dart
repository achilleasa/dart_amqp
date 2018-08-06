import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main() {
  Client client = new Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) {
    client.close().then((_) {
      exit(0);
    });
  });

  client
  .channel()
  .then((Channel channel) => channel.exchange("logs", ExchangeType.FANOUT))
  .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(null))
  .then((Consumer consumer) {
    print(" [*] Waiting for logs on private queue ${consumer.queue.name}. To exit, press CTRL+C");
    consumer.listen((AmqpMessage message) {
      print(" [x] ${message.payloadAsString}");
    });
  });

}