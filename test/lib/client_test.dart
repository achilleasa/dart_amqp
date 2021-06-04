library dart_amqp.test.client;

import 'dart:async';
import 'dart:io';

import "package:test/test.dart";

import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Client test:", () {
    Client client;

    tearDown(() async {
      await client.close();
    });

    test("fail to connect after 2 attempts", () async {
      ConnectionSettings settings = ConnectionSettings(
          port: 8765,
          maxConnectionAttempts: 2,
          reconnectWaitTime: const Duration(milliseconds: 10));
      client = Client(settings: settings);

      try {
        await client.connect();
      } catch (ex) {
        expect(ex, const TypeMatcher<ConnectionFailedException>());
        expect(ex.toString(), startsWith('ConnectionFailedException'));
      }
    });

    test("multiple open attampts should return the same future", () async {
      client = Client();
      Future connectFuture = client.connect();
      expect(client.connect(), equals(connectFuture));
      await connectFuture;
    });

    test("multiple close attampts should return the same future", () async {
      client = Client();
      await client.connect();
      Future closeFuture = client.close();
      expect(client.close(), equals(closeFuture));
      await closeFuture;
    });

    test("exception when exceeding negotiated channel limit", () async {
      ConnectionSettings settings =
          ConnectionSettings(tuningSettings: TuningSettings()..maxChannels = 1);
      client = Client(settings: settings);

      await client.channel();
      try {
        await client.channel();
      } catch (ex) {
        expect(ex, const TypeMatcher<StateError>());
        expect(ex.message,
            equals("Cannot allocate channel; channel limit exceeded (max 1)"));
      }
    });

    test("should be able to close a client connection after re-opening",
        () async {
      client = Client();
      await client.connect();
      Future firstClose = client.close();

      await firstClose.then((_) async {
        await client.connect();
        Future secondClose = client.close();

        await secondClose.then((_) {
          expect(identical(firstClose, secondClose), false);
        });
      });
    });
  });

  var certPath = "${Directory.current.path}/lib/mocks/certs";
  // When collecting code coverage metrics, current path will be the package root instead.
  if (!Directory(certPath).existsSync()) {
    certPath = "${Directory.current.path}/test/lib/mocks/certs";
  }
  var skipTLSTests = Platform.environment.containsKey("AMQP_RUN_TLS_TESTS")
      ? null
      : """

      To run the TLS tests first make sure that your local rabbit instance is
      configured with the following settings:

        listeners.ssl.default = 5671

        ssl_options.cacertfile = ${certPath}/ca_certificate.pem
        ssl_options.certfile   = ${certPath}/server_certificate.pem
        ssl_options.keyfile    = ${certPath}/server_key.pem
        ssl_options.verify     = verify_peer
        ssl_options.fail_if_no_peer_cert = false

      Then, run 'export AMQP_RUN_TLS_TESTS=true' before running the test suite.
      """;

  group("Client TLS test:", () {
    Client client;

    tearDown(() async {
      await client.close();
    });

    test("connect to server over TLS", () async {
      SecurityContext ctx = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificates("${certPath}/ca_certificate.pem");

      ConnectionSettings settings =
          ConnectionSettings(port: 5671, tlsContext: ctx);
      client = Client(settings: settings);
      await client.connect();
    });

    test("connect to server over TLS using client certificate", () async {
      SecurityContext ctx = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificates("${certPath}/ca_certificate.pem")
        ..useCertificateChain("${certPath}/client_certificate.pem")
        ..usePrivateKey("${certPath}/client_key.pem");

      ConnectionSettings settings =
          ConnectionSettings(port: 5671, tlsContext: ctx);
      client = Client(settings: settings);
      await client.connect();
    });
  }, skip: skipTLSTests);
}
