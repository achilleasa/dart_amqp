library dart_amqp.test.channels;

import "../../packages/unittest/unittest.dart";

import "../../lib/src/client.dart";
import "../../lib/src/enums.dart";
import "../../lib/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

// This test expects a local running rabbitmq instance at the default port
main({bool enableLogger : true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group
  ("Channels:", () {
    Client client;

    setUp(() {
      client = new Client();
    });

    tearDown(() {
      return client.close();
    });

    test("select() followed by commit()", () {
      return client
      .channel()
      .then((Channel channel) => channel.select())
      .then((Channel channel) => channel.commit());
    });

    test("select() followed by rollback()", () {
      return client
      .channel()
      .then((Channel channel) => channel.select())
      .then((Channel channel) => channel.rollback());
    });

    test("flow control: off", () {
      // Rabbit does not support setting flow control to on
      return client
      .channel()
      .then((Channel channel) => channel.flow(true));
    });

    group("exceptions:", () {

      test("sending data on a closed channel should raise an exception", () {
        return client
        .channel()
        .then((Channel channel) => channel.close())
        .then((Channel channel) {
          expect(() => channel.privateQueue(), throwsA((e) => e is StateError && e.message == "Channel has been closed"));
        });
      });


      test("commit() on a non-transactional channel should raise a precondition-failed error", () {
        client
        .channel()
        .then((Channel channel) => channel.commit())
        .then((_) => fail("Expected an exception to be thrown"))
        .catchError(expectAsync((e) {
          expect(e, new isInstanceOf<ChannelException>());
          expect((e as ChannelException).errorType, equals(ErrorType.PRECONDITION_FAILED));
        }));
      });

      test("rollback() on a non-transactional channel should raise a precondition-failed error", () {
        client
        .channel()
        .then((Channel channel) => channel.rollback())
        .then((_) => fail("Expected an exception to be thrown"))
        .catchError(expectAsync((e) {
          expect(e, new isInstanceOf<ChannelException>());
          expect((e as ChannelException).errorType, equals(ErrorType.PRECONDITION_FAILED));
          expect(e.toString(), startsWith("ChannelException(PRECONDITION_FAILED)"));
        }));
      });

      test("revocer()", () {
        return client
        .channel()
        .then((Channel channel) => channel.recover(true));
      });
    });
  });
}
