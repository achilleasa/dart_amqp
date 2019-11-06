library dart_amqp.test.exchanges;

import "dart:async";
import "package:test/test.dart";

import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/enums.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

// This test expects a local running rabbitmq instance at the default port
main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Exchanges:", () {
    Client client;
    Client client2;

    setUp(() {
      client = Client();
      client2 = Client();
    });

    tearDown(() async {
      await client.close();
      await client2.close();
    });

    test("check if unknown exchange exists", () async {
      try {
        Channel channel = await client.channel();
        await channel.exchange("foo123", ExchangeType.DIRECT, passive: true);
        fail("Expected an exception to be thrown");
      } catch (e) {
        expect(e, const TypeMatcher<ExchangeNotFoundException>());
        expect((e as ExchangeNotFoundException).errorType,
            equals(ErrorType.NOT_FOUND));
        expect(
            e.toString(), startsWith("ExchangeNotFoundException: NOT_FOUND"));
      }
    });

    test("declare exchange", () async {
      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      expect(exchange.channel, const TypeMatcher<Channel>());
      expect(exchange.name, equals("ex_test_1"));
      expect(exchange.type, equals(ExchangeType.DIRECT));
    });

    test("declare exchange and bind private queue consumer", () async {
      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      Consumer consumer = await exchange.bindPrivateQueueConsumer(["test"]);
      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);
    });

    test("declare exchange and bind multiple routing keys", () async {
      Channel channel = await client.channel();
      channel = await channel.qos(null, 1);
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      Consumer consumer =
          await exchange.bindPrivateQueueConsumer(["test", "foo", "bar"]);
      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);
    });

    test("declare exchange and publish message", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      Consumer consumer = await exchange.bindPrivateQueueConsumer(["test"]);

      // Listen for messages
      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsString, equals("Test message 1234"));
        expect(message.routingKey, equals("test"));

        // Check for exception with missing reply-to property
        expect(
            () => message.reply(""),
            throwsA((e) =>
                e is ArgumentError &&
                e.message ==
                    "No reply-to property specified in the incoming message"));

        testCompleter.complete();
      }));

      // Connect second client and publish message to exchange
      Channel channel2 = await client.channel();
      Exchange client2Exchange =
          await channel2.exchange("ex_test_1", ExchangeType.DIRECT);
      client2Exchange.publish("Test message 1234", "test");

      return testCompleter.future;
    });

    test("publish unrouteable message", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      channel.basicReturnListener((BasicReturnMessage message) {
        expect(message.replyCode, equals(312));
        expect(message.routingKey, equals("test"));
        testCompleter.complete();
      });
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      exchange.publish("Test message 1234", "test", mandatory: true);

      return testCompleter.future;
    });

    test("two client json conversation through an exchange", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      Consumer consumer = await exchange.bindPrivateQueueConsumer(["test"]);

      // Listen for messages
      consumer.listen((AmqpMessage message) {
        expect(message.payloadAsString, equals('{"message":"1234"}'));
        expect(message.payloadAsJson, equals({"message": "1234"}));
        expect(message.payload, equals(message.payloadAsString.codeUnits));
        expect(message.routingKey, equals("test"));
        expect(message.properties.corellationId, equals("123"));
        expect(message.exchangeName, equals("ex_test_1"));

        // Reply with echo to sender
        message.reply("echo:${message.payloadAsString}");
      });

      // Connect second client and publish message to excahnge
      Channel channel2 = await client2.channel();
      Exchange client2Exchange =
          await channel2.exchange("ex_test_1", ExchangeType.DIRECT);

      // Allocate private queue for response
      Queue replyQueue = await client2Exchange.channel.privateQueue();
      Consumer replyConsumer = await replyQueue.consume();

      // Bind reply listener
      replyConsumer.listen((AmqpMessage reply) {
        expect(reply.properties.corellationId, equals("123"));
        expect(reply.payloadAsString, equals('echo:{"message":"1234"}'));

        // Pass!
        testCompleter.complete();
      });

      // Send initial message via exchange
      client2Exchange.publish({"message": "1234"}, "test",
          properties: MessageProperties()
            ..corellationId = "123"
            ..replyTo = replyConsumer.queue.name);

      return testCompleter.future;
    });

    test("declare and delete exchange", () async {
      Channel channel = await client.channel();
      channel = await channel.qos(0, 1);
      Exchange exchange =
          await channel.exchange("ex_test_1", ExchangeType.DIRECT);
      await exchange.delete();
    });

    test("publish to FANOUT exchange without a routing key", () async {
      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_2", ExchangeType.FANOUT);
      exchange.publish("Hello", "");
    });

    test("bind queue to FANOUT exchange without a routing key", () async {
      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_2", ExchangeType.FANOUT);
      await exchange.bindPrivateQueueConsumer([]);
    });

    test("unbind queue from exchange", () async {
      Channel channel = await client.channel();
      Exchange exchange =
          await channel.exchange("ex_test_2", ExchangeType.FANOUT);
      Queue privateQueue = await exchange.channel.privateQueue();
      Queue boundQueue = await privateQueue.bind(exchange, "");
      await boundQueue.unbind(exchange, "");
    });

    group("exceptions", () {
      test("missing exchange name", () async {
        Channel channel = await client.channel();
        expect(
            () => channel.exchange(null, null),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message == "The name of the exchange cannot be empty"));
      });

      test("missing exchange type", () async {
        Channel channel = await client.channel();
        expect(
            () => channel.exchange("foo", null),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message ==
                    "The type of the exchange needs to be specified"));
      });

      test("missing routing key for non-fanout exchange publish", () async {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("test", ExchangeType.DIRECT);
        expect(
            () => exchange.publish("foo", null),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message == "A valid routing key needs to be specified"));
      });

      test("missing private queue routing key for non-fanout exchange consumer",
          () async {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("test", ExchangeType.DIRECT);
        expect(
            () => exchange.bindPrivateQueueConsumer([]),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message ==
                    "One or more routing keys needs to be specified for this exchange type"));
      });

      test("bind to non-FANOUT exchange without specifying routing key",
          () async {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("test", ExchangeType.DIRECT);
        Queue queue = await exchange.channel.privateQueue();
        expect(
            () => queue.bind(exchange, ""),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message ==
                    "A routing key needs to be specified to bind to this exchange type"));
      });

      test("unbind from non-FANOUT exchange without specifying routing key",
          () async {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("test", ExchangeType.DIRECT);

        Queue queue = await exchange.channel.privateQueue();
        queue = await queue.bind(exchange, "test");
        expect(
            () => queue.unbind(exchange, ""),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message ==
                    "A routing key needs to be specified to unbind from this exchange type"));
      });

      test("bind queue to null exchange", () async {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("test", ExchangeType.DIRECT);

        Queue queue = await exchange.channel.privateQueue();
        expect(
            () => queue.bind(null, ""),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message == "Exchange cannot be null"));
      });

      test("unbind queue from null exchange", () async {
        Channel channel = await client.channel();
        Exchange exchange = await channel.exchange("test", ExchangeType.DIRECT);

        Queue queue = await exchange.channel.privateQueue();
        queue = await queue.bind(exchange, "test");
        expect(
            () => queue.unbind(null, ""),
            throwsA((ex) =>
                ex is ArgumentError &&
                ex.message == "Exchange cannot be null"));
      });

      test("declare exchange and bind named queue consumer", () async {
        Channel channel = await client.channel();
        Exchange exchange =
            await channel.exchange("ex_test_1", ExchangeType.DIRECT);
        Consumer consumer = await exchange.bindQueueConsumer("my_test_queue", ["test"]);
        expect(consumer.channel, const TypeMatcher<Channel>());
        expect(consumer.queue, const TypeMatcher<Queue>());
        expect(consumer.tag, isNotEmpty);
        expect(consumer.queue.name, equals("my_test_queue"));
      });
    });
  });
}
