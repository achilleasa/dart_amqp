import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main(List<String> args) async {
  var useClientCert = false;
  if (args.length == 1 && args[0] == "--use-client-cert") {
    print("Using client certificate for authenticating to server");
    useClientCert = true;
  }

  Client client = getClient(useClientCert);

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) async {
    await client.close();
    exit(0);
  });

  Channel channel = await client.channel();
  Queue queue = await channel.queue("hello");
  Consumer consumer = await queue.consume();
  print(" [*] Waiting for messages. To exit, press CTRL+C");
  consumer.listen((message) {
    print(" [x] Received ${message.payloadAsString}");
  });
}

Client getClient(bool useClientCert) {
  var certPath = "${Directory.current.path}/../../test/lib/mocks/certs";
  if (!Platform.environment.containsKey("AMQP_USE_TLS")) {
    print("""

      To run the this example first make sure that your local rabbit instance is
      configured with the following settings:

        listeners.ssl.default = 5671

        ssl_options.cacertfile = $certPath/ca_certificate.pem
        ssl_options.certfile   = $certPath/server_certificate.pem
        ssl_options.keyfile    = $certPath/server_key.pem
        ssl_options.verify     = verify_peer
        ssl_options.fail_if_no_peer_cert = false

      Then, run 'export AMQP_USE_TLS=true' before running this example.
      """);
    exit(1);
  }

  SecurityContext ctx = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificates("$certPath/ca_certificate.pem");

  if (useClientCert) {
    ctx
      ..useCertificateChain("$certPath/client_certificate.pem")
      ..usePrivateKey("$certPath/client_key.pem");
  }

  ConnectionSettings settings = ConnectionSettings(port: 5671, tlsContext: ctx);

  return Client(settings: settings);
}
