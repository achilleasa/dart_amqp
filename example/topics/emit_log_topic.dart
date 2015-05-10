import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) {
  if (args.length < 2) {
    print("""
    Error: invalid arguments. Please invoke as:

    dart emit_log_topic.dart routing-key message

    Where:
        routing-key = dot (.) delimited value like anonymous.info or kernel.error

""");
    exit(1);
  }

  String routingKey = args.first;

  Client client = new Client();
  client
  .channel()
  .then((Channel channel) => channel.exchange("topic_logs", ExchangeType.TOPIC))
  .then((Exchange exchange) {
    String message = args.sublist(1).join(' ');
    // Use 'severity' as our routing key
    exchange.publish(message, routingKey);
    print(" [x] Sent [${routingKey}] ${message}");
    return client.close();
  });
}