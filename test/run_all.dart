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
  bool enableLogger = args.indexOf('--disable-logger') == -1;

  String allArgs = args.join(".");
  bool runAll = args.isEmpty || allArgs == '--disable-logger';

  //useCompactVMConfiguration();
//
  if (runAll || (new RegExp("enums")).hasMatch(allArgs)) {
    enums.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("encoder-decoder")).hasMatch(allArgs)) {
    encode_decode.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("exception-handling")).hasMatch(allArgs)) {
    exceptions.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("amqp-decoder")).hasMatch(allArgs)) {
    amqp_decoder.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("authentication")).hasMatch(allArgs)) {
    auth.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("channels")).hasMatch(allArgs)) {
    channels.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("queues")).hasMatch(allArgs)) {
    queues.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("exchanges")).hasMatch(allArgs)) {
    exchanges.main(enableLogger : enableLogger);
  }

  if (runAll || (new RegExp("client")).hasMatch(allArgs)) {
    client.main(enableLogger : enableLogger);
  }
}