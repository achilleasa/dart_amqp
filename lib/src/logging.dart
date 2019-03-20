library dart_amqp.logger;

import "dart:convert";
import "package:logging/logging.dart";

// Logging
part "logging/logger.dart";

// A indenting json encoder used by the toString() method of messages
const JsonEncoder indentingJsonEncoder = JsonEncoder.withIndent(" ");
