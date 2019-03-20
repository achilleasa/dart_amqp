library dart_amqp.test;

import "lib/enum_test.dart" as enums;
import "lib/encode_decode_test.dart" as encode_decode;
import "lib/exception_handling_test.dart" as exceptions;
import "lib/amqp_decoder_test.dart" as amqp_decoder;
import "lib/auth_test.dart" as auth;
import "lib/channel_test.dart" as channels;
import "lib/queue_test.dart" as queues;
import "lib/exchange_test.dart" as exchanges;
import "lib/client_test.dart" as client;

void main(List<String> args) {
  // Check if we need to disable our loggers
  bool enableLogger = args.indexOf('--enable-logger') != -1;

  String allArgs = args.join(".");
  bool runAll = args.isEmpty || allArgs == '--enable-logger';

  //useCompactVMConfiguration();
//
  if (runAll || (RegExp("enums")).hasMatch(allArgs)) {
    enums.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("encoder-decoder")).hasMatch(allArgs)) {
    encode_decode.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("exception-handling")).hasMatch(allArgs)) {
    exceptions.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("amqp-decoder")).hasMatch(allArgs)) {
    amqp_decoder.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("authentication")).hasMatch(allArgs)) {
    auth.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("channels")).hasMatch(allArgs)) {
    channels.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("queues")).hasMatch(allArgs)) {
    queues.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("exchanges")).hasMatch(allArgs)) {
    exchanges.main(enableLogger: enableLogger);
  }

  if (runAll || (RegExp("client")).hasMatch(allArgs)) {
    client.main(enableLogger: enableLogger);
  }
}
