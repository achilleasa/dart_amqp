import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) {
  Client client = Client();
  client
      .channel()
      .then((Channel channel) => channel.queue("task_queue", durable: true))
      .then((Queue queue) {
    String message = args.length == 0 ? "Hello World!" : args.join(" ");
    queue.publish(message, properties: MessageProperties.persistentMessage());
    print(" [x] Sent ${message}");
    return client.close();
  });
}
