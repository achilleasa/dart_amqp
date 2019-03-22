import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) {
  if (args.length < 2 || ["info", "warning", "error"].indexOf(args[0]) == -1) {
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
  client
      .channel()
      .then((Channel channel) =>
          channel.exchange("direct_logs", ExchangeType.DIRECT))
      .then((Exchange exchange) {
    String message = args.sublist(1).join(' ');
    // Use 'severity' as our routing key
    exchange.publish(message, severity);
    print(" [x] Sent [${severity}] ${message}");
    return client.close();
  });
}
