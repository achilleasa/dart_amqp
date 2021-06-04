import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) async {
  Client client = Client();
  Channel channel = await client.channel();
  Queue queue = await channel.queue("task_queue", durable: true);
  String message = args.isEmpty ? "Hello World!" : args.join(" ");
  queue.publish(message, properties: MessageProperties.persistentMessage());
  print(" [x] Sent $message");
  await client.close();
}
