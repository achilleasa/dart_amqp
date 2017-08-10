library dart_amqp.test.queues;

import "dart:async";

import "../../packages/unittest/unittest.dart";

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

  group("Queues:", () {
    Client client;

    setUp(() {
      client = new Client();
    });

    tearDown(() {
      return client.close();
    });

    test("check if unknown queue exists", () {
      client
      .channel()
      .then((Channel channel) => channel.queue("foo", passive : true))
      .then((_) => fail("Expected an exception to be thrown"))
      .catchError(expectAsync((e) {
        expect(e, new isInstanceOf<QueueNotFoundException>());
        expect((e as QueueNotFoundException).errorType, equals(ErrorType.NOT_FOUND));
        expect(e.toString(), startsWith("QueueNotFoundException: NOT_FOUND"));
      }));
    });

    test("create private queue", () {
      client
      .channel()
      .then((Channel channel) => channel.privateQueue())
      .then(expectAsync((Queue queue) {
        expect(queue.channel, new isInstanceOf<Channel>());
        expect(queue.name, isNotEmpty);
        expect(queue.consumerCount, equals(0));
        expect(queue.messageCount, equals(0));
      }));
    });

    test("create public queue", () {
      client
      .channel()
      .then((Channel channel) => channel.queue("test_1"))
      .then(expectAsync((Queue queue) {
        expect(queue.channel, new isInstanceOf<Channel>());
        expect(queue.name, isNotEmpty);
        expect(queue.consumerCount, equals(0));
        expect(queue.messageCount, equals(0));
      }));
    });

    test("Check the existance of a created queue", () {
      client
      .channel()
      .then((Channel channel) => channel.privateQueue())
      .then(expectAsync((Queue privateQueue) {
        // Check existance
        privateQueue.channel.queue(privateQueue.name, passive : true)
        .then(expectAsync((Queue queue) {
          expect(queue.name, equals(privateQueue.name));
        }));
      }));
    });
  });

  group("inter-queue messaging:", () {
    Client client;
    Client client2;

    setUp(() {
      client = new Client();
      client2 = new Client();
    });

    tearDown(() {
      return Future.wait(
          [
            client.close(),
            client2.close()
          ]);
    });

    test("queue message delivery", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.queue("test_2"))
      .then((Queue testQueue) => testQueue.consume())
      .then((Consumer consumer) {
        expect(consumer.channel, new isInstanceOf<Channel>());
        expect(consumer.queue, new isInstanceOf<Queue>());
        expect(consumer.tag, isNotEmpty);

        consumer.listen(expectAsync((AmqpMessage message) {
          expect(message.payloadAsString, equals("Test payload"));
          testCompleter.complete();
        }));

        // Using second client publish a message to the queue
        client2
        .channel()
        .then((Channel channel) => channel.queue(consumer.queue.name))
        .then((Queue target) => target.publish("Test payload"));
      });

      return testCompleter.future;
    });

    test("queue JSON message delivery (auto-filled content type)", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.queue("test_2"))
      .then((Queue testQueue) => testQueue.consume())
      .then((Consumer consumer) {
        expect(consumer.channel, new isInstanceOf<Channel>());
        expect(consumer.queue, new isInstanceOf<Queue>());
        expect(consumer.tag, isNotEmpty);

        consumer.listen(expectAsync((AmqpMessage message) {
          expect(message.payloadAsJson, equals({"message" : "Test payload"}));
          expect(message.properties.contentType, equals("application/json"));
          testCompleter.complete();
        }));

        // Using second client publish a message to the queue
        client2
        .channel()
        .then((Channel channel) => channel.queue(consumer.queue.name))
        .then((Queue target) => target.publish({"message" : "Test payload"}));
      });

      return testCompleter.future;
    });

    test("queue JSON message delivery (auto-filled content type in existing persistent message property set)", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.queue("test_2"))
      .then((Queue testQueue) => testQueue.consume())
      .then((Consumer consumer) {
        expect(consumer.channel, new isInstanceOf<Channel>());
        expect(consumer.queue, new isInstanceOf<Queue>());
        expect(consumer.tag, isNotEmpty);

        // Use second accuracy
        DateTime now = new DateTime.now();
        now = now.subtract(new Duration(milliseconds : now.millisecond, microseconds: now.microsecond));

        consumer.listen(expectAsync((AmqpMessage message) {
          expect(message.payloadAsJson, equals({"message" : "Test payload"}));
          expect(message.properties.contentType, equals("application/json"));
          expect(message.properties.headers, equals({
            'X-HEADER' : 'ok'
          }));
          expect(message.properties.priority, equals(1));
          expect(message.properties.corellationId, equals("123"));
          expect(message.properties.replyTo, equals("/dev/null"));
          expect(message.properties.expiration, equals("60000"));
          expect(message.properties.messageId, equals("0xf00"));
          expect(message.properties.timestamp, equals(now));
          expect(message.properties.type, equals("test"));
          expect(message.properties.userId, equals("guest"));
          expect(message.properties.appId, equals("unit-test"));
          testCompleter.complete();
        }));

        // Using second client publish a message with full properties to the queue
        client2
        .channel()
        .then((Channel channel) => channel.queue(consumer.queue.name))
        .then((Queue target) => target.publish(
            {"message" : "Test payload"},
            properties : new MessageProperties.persistentMessage()
              ..headers = {
              'X-HEADER' : 'ok'
            }
              ..priority = 1
              ..corellationId = "123"
              ..replyTo = "/dev/null"
              ..expiration = "60000" // 60 sec
              ..messageId = "0xf00"
              ..timestamp = now
              ..type = "test"
              ..userId = "guest"
              ..appId = "unit-test"
        ));
      });

      return testCompleter.future;
    });

    test("queue message delivery with ack", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.queue("test_3"))
      .then((Queue testQueue) => testQueue.consume(noAck : false))
      .then((Consumer consumer) {
        expect(consumer.channel, new isInstanceOf<Channel>());
        expect(consumer.queue, new isInstanceOf<Queue>());
        expect(consumer.tag, isNotEmpty);

        consumer.listen(expectAsync((AmqpMessage message) {
          expect(message.payloadAsString, equals("Test payload"));
          message.ack();
          testCompleter.complete();
        }));

        // Using second client publish a message to the queue (request ack)
        client2
        .channel()
        .then((Channel channel) => channel.queue(consumer.queue.name))
        .then((Queue target) => target.publish("Test payload", mandatory : true));
      });

      return testCompleter.future;
    });

    test("reject delivered message", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.queue("test_3"))
      .then((Queue testQueue) => testQueue.consume(noAck : false))
      .then((Consumer consumer) {
        expect(consumer.channel, new isInstanceOf<Channel>());
        expect(consumer.queue, new isInstanceOf<Queue>());
        expect(consumer.tag, isNotEmpty);

        consumer.listen(expectAsync((AmqpMessage message) {
          expect(message.payloadAsString, equals("Test payload"));
          message.reject(false);
          testCompleter.complete();
        }));

        // Using second client publish a message to the queue (request ack)
        client2
        .channel()
        .then((Channel channel) => channel.queue(consumer.queue.name))
        .then((Queue target) => target.publish("Test payload", mandatory : true));
      });

      return testCompleter.future;
    });

    test("queue cancel consumer", () {
      Completer testCompleter = new Completer();
      client
      .channel()
      .then((Channel channel) => channel.queue("test_3"))
      .then((Queue testQueue) => testQueue.consume(noAck : false))
      .then((Consumer consumer) {

        consumer.listen((AmqpMessage message) {
          fail("Received unexpected AMQP message");
        }, onDone : () {
          testCompleter.complete();
        });

        // Cancel the consumer and wait for the stream controller to close
        consumer.cancel();
      });

      return testCompleter.future;
    });

    test("delete queue", () {
      client
      .channel()
      .then((Channel channel) => channel.queue("test_3"))
      .then((Queue testQueue) => testQueue.delete())
      .then(expectAsync((Queue queue) {

      }));
    });

    test("consuming with same consumer tag on same channel should return identical consumer", () {
      Completer testCompleter = new Completer();

      client
      .channel()
      .then((Channel channel) => channel.queue("test_3"))
      .then((Queue testQueue) => testQueue.consume(consumerTag : "test_tag_1"))
      .then((Consumer consumer1) {
        consumer1.queue
        .consume(consumerTag : "test_tag_1")
        .then((Consumer consumer2) {
          expect(true, identical(consumer1, consumer2));
          testCompleter.complete();
        });
      });

      return testCompleter.future;
    });

    test("purge a queue", () {
      return client
      .channel()
      .then((Channel channel) => channel.queue("test_4"))
      .then((Queue queue) => queue.purge());
    });

    group("exceptions:", () {
      test("unsupported message payload", () {

        client
        .channel()
        .then((Channel channel) => channel.queue("test_99"))
        .then((Queue queue) => queue.publish(new StreamController()))
        .catchError(expectAsync((ex) {
          expect(ex, new isInstanceOf<ArgumentError>());
          expect(ex.message, equals("Message payload should be either a Map, an Iterable, a String or an UInt8List instance"));
        }));

      });

      test("server closes channel after publishing message with invalid properties; next channel operation should fail", () {

        client
        .channel()
        .then((Channel channel) => channel.queue("test_100"))
        .then((Queue queue) {
          queue.publish("invalid properties test",
          properties : new MessageProperties()
            ..expiration = "undefined"
          );

          return queue.channel.queue("other_queue");
        })
        .catchError(expectAsync((ex) {
          expect(ex, new isInstanceOf<ChannelException>());
          expect(ex.toString(), equals("ChannelException(PRECONDITION_FAILED): PRECONDITION_FAILED - invalid expiration 'undefined': no_integer"));
        }));

      });

      test("trying to publish to a channel closed by a prior invalid published message; next publish should fail", () {
        Completer testCompleter = new Completer();

        client
        .channel()
        .then((Channel channel) => channel.queue("test_100"))
        .then((Queue queue) {
          queue.publish("invalid properties test",
          properties : new MessageProperties()
            ..expiration = "undefined"
          );

          new Future.delayed(const Duration(seconds: 1))
          .then((_) {
            queue.publish("test");
          })
          .catchError(expectAsync((ex) {
            expect(ex, new isInstanceOf<ChannelException>());
            expect(ex.toString(), equals("ChannelException(PRECONDITION_FAILED): PRECONDITION_FAILED - invalid expiration 'undefined': no_integer"));

            testCompleter.complete();
          }));
        });

        return testCompleter.future;
      });

    });

  });
}
