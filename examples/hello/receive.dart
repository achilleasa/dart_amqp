import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main() {
  Client client = new Client();

  // Setup a signal hundler to cleanly exit if CTRL+C is pressed
  ProcessSignal.SIGINT.watch().listen((_) {
    client.close().then((_) {
      exit(0);
    });
  });

  client
  .channel()
  .then((Channel channel) => channel.queue("hello"))
  .then((Queue queue) => queue.consume())
  .then((Consumer consumer) {
    print(" [*] Waiting for messages. To exit, press CTRL+C");
    consumer.listen((AmqpMessage message) {
      print(" [x] Received ${message.payloadAsString}");
    });
  });
}