library dart_amqp.test.exchanges;

import "dart:async";
import "package:test/test.dart";

import "../../lib/src/client.dart";
import "../../lib/src/protocol.dart";
import "../../lib/src/enums.dart";
import "../../lib/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

// This test expects a local running rabbitmq instance at the default port
main({bool enableLogger : true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group
  ("Exchanges:", () {
    Client client;
    Client client2;

    setUp(() {
      client = new Client();
      client2 = new Client();
    });

    tearDown(() {
      return client.close()
      .then((_) => client2.close());
    });

    test("check if unknown exchange exists", () {
      client
      .channel()
      .then((Channel channel) => channel.exchange("foo123", ExchangeType.DIRECT, passive : true))
      .then((_) => fail("Expected an exception to be thrown"))
      .catchError(expectAsync1((e) {
        expect(e, const TypeMatcher<ExchangeNotFoundException>());
        expect((e as ExchangeNotFoundException).errorType, equals(ErrorType.NOT_FOUND));
        expect(e.toString(), startsWith("ExchangeNotFoundException: NOT_FOUND"));
      }));
    });

    test("declare exchange", () {
      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
      .then(expectAsync1((Exchange exchange) {
        expect(exchange.channel, const TypeMatcher<Channel>());
        expect(exchange.name, equals("ex_test_1"));
        expect(exchange.type, equals(ExchangeType.DIRECT));
      }));
    });

    test("declare exchange and bind private queue consumer", () {
      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
      .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(["test"]))
      .then(expectAsync1((Consumer consumer) {
        expect(consumer.channel, const TypeMatcher<Channel>());
        expect(consumer.queue, const TypeMatcher<Queue>());
        expect(consumer.tag, isNotEmpty);
      }));

    });

    test("declare exchange and bind multiple routing keys", () {
      client
      .channel()
      .then((Channel channel) => channel.qos(null, 1))
      .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
      .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(["test", "foo", "bar"]))
      .then(expectAsync1((Consumer consumer) {
        expect(consumer.channel, const TypeMatcher<Channel>());
        expect(consumer.queue, const TypeMatcher<Queue>());
        expect(consumer.tag, isNotEmpty);
      }));

    });

    test("declare exchange and publish message", () {
      Completer testCompleter = new Completer();
      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
      .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(["test"]))
      .then((Consumer consumer) {
        // Listen for messages
        consumer.listen(expectAsync1((AmqpMessage message) {
          expect(message.payloadAsString, equals("Test message 1234"));
          expect(message.routingKey, equals("test"));

          // Check for exception with missing reply-to property
          expect(() => message.reply(""), throwsA((e) => e is ArgumentError && e.message == "No reply-to property specified in the incoming message"));

          testCompleter.complete();
        }));

        // Connect second client and publish message to excahnge
        client2
        .channel()
        .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
        .then((Exchange client2Exchange) => client2Exchange.publish("Test message 1234", "test"));
      });

      return testCompleter.future;

    });

    test("publish unrouteable message", () {
      Completer testCompleter = new Completer();
      client
      .channel()
      .then((Channel channel) {
        channel.basicReturnListener((BasicReturnMessage message){
          expect(message.replyCode, equals(312));
          expect(message.routingKey, equals("test"));
          testCompleter.complete();
        });
        return channel.exchange("ex_test_1", ExchangeType.DIRECT);
      }).then((Exchange exchange)=>exchange.publish("Test message 1234", "test", mandatory:true));
      return testCompleter.future;
    });

    test("two client json conversation through an exchange", () {
      Completer testCompleter = new Completer();
      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
      .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(["test"]))
      .then((Consumer consumer) {

        // Listen for messages
        consumer.listen((AmqpMessage message) {
          expect(message.payloadAsString, equals('{"message":"1234"}'));
          expect(message.payloadAsJson, equals({"message":"1234"}));
          expect(message.payload, equals(message.payloadAsString.codeUnits));
          expect(message.routingKey, equals("test"));
          expect(message.properties.corellationId, equals("123"));
          expect(message.exchangeName, equals("ex_test_1"));

          // Reply with echo to sender
          message.reply("echo:${message.payloadAsString}");
        });

        // Connect second client and publish message to excahnge
        client2
        .channel()
        .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
        .then((Exchange client2Exchange) {
          // Allocate private queue for response
          client2Exchange.channel.privateQueue()
          .then((Queue replyQueue) => replyQueue.consume())
          .then((Consumer replyConsumer) {

            // Bind reply listener
            replyConsumer.listen((AmqpMessage reply) {
              expect(reply.properties.corellationId, equals("123"));
              expect(reply.payloadAsString, equals('echo:{"message":"1234"}'));

              // Pass!
              testCompleter.complete();
            });

            // Send initial message via exchange
            client2Exchange.publish(
                {"message" : "1234"},
                "test",
                properties : new MessageProperties()
                  ..corellationId = "123"
                  ..replyTo = replyConsumer.queue.name
            );
          });
        });
      });

      return testCompleter.future;

    });

    test("declare and delete exchange", () {
      client
      .channel()
      .then((Channel channel) => channel.qos(0, 1))
      .then((Channel channel) => channel.exchange("ex_test_1", ExchangeType.DIRECT))
      .then((Exchange exchange) => exchange.delete())
      .then(expectAsync1((Exchange exchange) {
      }));

    });

    test("publish to FANOUT exchange without a routing key", () {
      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_2", ExchangeType.FANOUT))
      .then((Exchange exchange) => exchange.publish("Hello", ""))
      .then(expectAsync1((_) {
      }));

    });

    test("bind queue to FANOUT exchange without a routing key", () {
      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_2", ExchangeType.FANOUT))
      .then((Exchange exchange) => exchange.bindPrivateQueueConsumer([]))
      .then(expectAsync1((Consumer consumer) {
      }));

    });

    test("unbind queue from exchange", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.exchange("ex_test_2", ExchangeType.FANOUT))
      .then((Exchange exchange) {
        exchange.channel
        .privateQueue()
        .then((Queue privateQueue) => privateQueue.bind(exchange, ""))
        .then((Queue boundQueue) => boundQueue.unbind(exchange, ""))
        .then((Queue unboundQueue) {
          testCompleter.complete();
        });
      });

      return testCompleter.future;
    });

    group("exceptions", () {
      test("missing exchange name", () {
        return client
        .channel()
        .then((Channel channel) {
          expect(() => channel.exchange(null, null), throwsA((ex) => ex is ArgumentError && ex.message == "The name of the exchange cannot be empty"));
        });
      });

      test("missing exchange type", () {
        return client
        .channel()
        .then((Channel channel) {
          expect(() => channel.exchange("foo", null), throwsA((ex) => ex is ArgumentError && ex.message == "The type of the exchange needs to be specified"));
        });
      });

      test("missing routing key for non-fanout exchange publish", () {
        return client
        .channel()
        .then((Channel channel) => channel.exchange("test", ExchangeType.DIRECT))
        .then((Exchange exchange) {
          expect(() => exchange.publish("foo", null), throwsA((ex) => ex is ArgumentError && ex.message == "A valid routing key needs to be specified"));
        });
      });

      test("missing private queue routing key for non-fanout exchange consumer", () {
        return client
        .channel()
        .then((Channel channel) => channel.exchange("test", ExchangeType.DIRECT))
        .then((Exchange exchange) {
          expect(() => exchange.bindPrivateQueueConsumer([]), throwsA((ex) => ex is ArgumentError && ex.message == "One or more routing keys needs to be specified for this exchange type"));
        });
      });

      test("bind to non-FANOUT exchange without specifying routing key", () {
        Completer testCompleter = new Completer();

        client
        .channel()
        .then((Channel channel) => channel.exchange("test", ExchangeType.DIRECT))
        .then((Exchange exchange) {
          exchange.channel
          .privateQueue()
          .then((Queue queue) {
            expect(() => queue.bind(exchange, ""), throwsA((ex) => ex is ArgumentError && ex.message == "A routing key needs to be specified to bind to this exchange type"));
            testCompleter.complete();
          });
        });

        return testCompleter.future;
      });

      test("unbind from non-FANOUT exchange without specifying routing key", () {
        Completer testCompleter = new Completer();

        client
        .channel()
        .then((Channel channel) => channel.exchange("test", ExchangeType.DIRECT))
        .then((Exchange exchange) {
          exchange.channel
          .privateQueue()
          .then((Queue queue) => queue.bind(exchange, "test"))
          .then((Queue queue) {
            expect(() => queue.unbind(exchange, ""), throwsA((ex) => ex is ArgumentError && ex.message == "A routing key needs to be specified to unbind from this exchange type"));
            testCompleter.complete();
          });
        });

        return testCompleter.future;
      });

      test("bind queue to null exchange", () {
        Completer testCompleter = new Completer();

        client
        .channel()
        .then((Channel channel) => channel.exchange("test", ExchangeType.DIRECT))
        .then((Exchange exchange) {
          exchange.channel
          .privateQueue()
          .then((Queue queue) {
            expect(() => queue.bind(null, ""), throwsA((ex) => ex is ArgumentError && ex.message == "Exchange cannot be null"));
            testCompleter.complete();
          });
        });

        return testCompleter.future;
      });

      test("unbind queue from null exchange", () {
        Completer testCompleter = new Completer();

        client
        .channel()
        .then((Channel channel) => channel.exchange("test", ExchangeType.DIRECT))
        .then((Exchange exchange) {
          exchange.channel
          .privateQueue()
          .then((Queue queue) => queue.bind(exchange, "test"))
          .then((Queue queue) {
            expect(() => queue.unbind(null, ""), throwsA((ex) => ex is ArgumentError && ex.message == "Exchange cannot be null"));
            testCompleter.complete();
          });
        });

        return testCompleter.future;
      });
    });
  });
}
