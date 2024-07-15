import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main(List<String> args) async {
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

  Client client = Client();
  Channel channel = await client.channel();
  Exchange exchange = await channel.exchange("topic_logs", ExchangeType.TOPIC);
  String message = args.sublist(1).join(' ');
  // Use 'severity' as our routing key
  exchange.publish(message, routingKey);
  print(" [x] Sent [$routingKey] $message");
  await client.close();
}
