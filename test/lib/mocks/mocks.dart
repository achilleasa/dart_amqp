library dart_amqp.tests.mocks;

import "dart:typed_data";
import "package:universal_io/io.dart";
import "dart:async";
import "dart:convert";

import "package:logging/logging.dart";
import "package:mockito/mockito.dart";

import "package:dart_amqp/src/protocol.dart";

part "server_mocks.dart";
part "message_mocks.dart";

final Logger mockLogger = Logger("MockLogger");
bool initializedLogger = false;

void initLogger() {
  if (initializedLogger == true) {
    return;
  }
  initializedLogger = true;
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print(
        "[${rec.level.name}]\t[${rec.time}]\t[${rec.loggerName}]:\t${rec.message}");
  });
}
