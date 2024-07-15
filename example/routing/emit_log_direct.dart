import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main(List<String> args) async {
  if (args.length < 2 || !["info", "warning", "error"].contains(args[0])) {
    print("""
    Error: invalid arguments. Please invoke as:

    dart emit_log_direct.dart severity message

    Where:
        severity = info, warning or error

""");
    exit(1);
  }

  String severity = args.first;

  Client client = Client();
  Channel channel = await client.channel();
  Exchange exchange =
      await channel.exchange("direct_logs", ExchangeType.DIRECT);

  String message = args.sublist(1).join(' ');
  // Use 'severity' as our routing key
  exchange.publish(message, severity);
  print(" [x] Sent [$severity] $message");
  await client.close();
}
