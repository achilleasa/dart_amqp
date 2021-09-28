import "dart:async";
import "package:dart_amqp/dart_amqp.dart";

void main() async {
  Completer done = Completer();
  Client client = Client();
  Channel channel = await client.channel();
  Queue queue = await channel.privateQueue();

  // To work with publish confirmations we first need to enable support for
  // confirmations on the channel used by our queue.
  await queue.channel.confirmPublishedMessages();

  // Then register a handler to process publish notifications.
  queue.channel.publishNotifier((PublishNotification notification) {
    Object? msg = notification.message;
    String? corId = notification.properties?.corellationId;
    bool ack = notification.published;
    print(
        " [!] received delivery notification: msg: '$msg', correlation ID: '$corId', ACK'd?: $ack");
    done.complete();
  });

  MessageProperties msgProps = MessageProperties()..corellationId = "42";
  queue.publish("Hello World!", properties: msgProps);
  print(" [x] Sent 'Hello World!'; waiting for delivery confirmation");

  await done.future;
  await client.close();
}
