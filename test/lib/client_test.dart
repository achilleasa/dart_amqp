library dart_amqp.test.client;

import 'dart:async';
import "package:universal_io/io.dart";

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
    late Client client;

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
        expect((ex as StateError).message,
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

        ssl_options.cacertfile = $certPath/ca_certificate.pem
        ssl_options.certfile   = $certPath/server_certificate.pem
        ssl_options.keyfile    = $certPath/server_key.pem
        ssl_options.verify     = verify_peer
        ssl_options.fail_if_no_peer_cert = false

      Then, run 'export AMQP_RUN_TLS_TESTS=true' before running the test suite.
      """;

  group("Client TLS test:", () {
    late Client client;

    tearDown(() async {
      await client.close();
    });

    test("connect to server over TLS", () async {
      SecurityContext ctx = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificates("$certPath/ca_certificate.pem");

      ConnectionSettings settings =
          ConnectionSettings(port: 5671, tlsContext: ctx);
      client = Client(settings: settings);
      await client.connect();
    });

    test("connect to server over TLS using client certificate", () async {
      SecurityContext ctx = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificates("$certPath/ca_certificate.pem")
        ..useCertificateChain("$certPath/client_certificate.pem")
        ..usePrivateKey("$certPath/client_key.pem");

      ConnectionSettings settings =
          ConnectionSettings(port: 5671, tlsContext: ctx);
      client = Client(settings: settings);
      await client.connect();
    });

    test("bad certificate handler", () async {
      Completer testCompleter = Completer();

      SecurityContext ctx = SecurityContext(withTrustedRoots: true);
      ConnectionSettings settings = ConnectionSettings(
          port: 5671,
          tlsContext: ctx,
          onBadCertificate: (X509Certificate cert) {
            print(
                " [x] onBadCertificate: allowing TLS connection to be established even though we cannot verify the certificate");
            testCompleter.complete();
            return true; // allow connection to proceed
          });
      client = Client(settings: settings);
      await client.connect();

      return testCompleter.future;
    });
  }, skip: skipTLSTests);

  group("Client heartbeat test:", () {
    late Client client;
    late mock.MockServer server;
    late FrameWriter frameWriter;
    late TuningSettings tuningSettings;
    setUp(() {
      tuningSettings = TuningSettings();
      frameWriter = FrameWriter(tuningSettings);
      server = mock.MockServer();
      client = Client(
        settings: ConnectionSettings(
          port: 9000,
          tuningSettings: tuningSettings,
        ),
      );
      return server.listen('127.0.0.1', 9000);
    });

    tearDown(() async {
      await client.close();
      await server.shutdown();
    });

    test("client disables heartbeats if they are not enabled by the client",
        () async {
      server.generateHandshakeMessages(frameWriter,
          heartbeatPeriod: const Duration(seconds: 42));

      // Encode final connection close
      frameWriter.writeMessage(0, mock.ConnectionCloseOkMock());
      server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
      frameWriter.outputEncoder.writer.clear();

      tuningSettings.heartbeatPeriod = Duration.zero;
      await client.connect();

      // Client should force heartbeatPeriod to Duration.zero even when the
      // server requests a non-zero heartbeat period.
      expect(client.tuningSettings.heartbeatPeriod, equals(Duration.zero));
    });

    test("client raises exception if server stops sending heartbeats",
        () async {
      server.generateHandshakeMessages(frameWriter,
          heartbeatPeriod: const Duration(seconds: 1));

      try {
        tuningSettings.heartbeatPeriod = const Duration(seconds: 123);
        await client.connect();
        // The effective period is 1s; calculated as:
        // min(server period, client period)
        expect(client.tuningSettings.heartbeatPeriod,
            equals(const Duration(seconds: 1)));

        // Perform a blocking call until we miss
        // tuningSettings.maxMissedHeartbeats consecutive heartbeats.
        await client.channel();
      } catch (e) {
        expect(e, const TypeMatcher<HeartbeatFailedException>());
        expect(
            (e as HeartbeatFailedException).message,
            equals(
                "Server did not respond to heartbeats for 1s (missed consecutive heartbeats: 3)"));

        // Encode final connection close
        frameWriter.writeMessage(0, mock.ConnectionCloseOkMock());
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
        frameWriter.outputEncoder.writer.clear();
      }
    });
  });
}
