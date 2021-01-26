part of dart_amqp.protocol;

class TuningSettings {
  int maxChannels = 0;

  int maxFrameSize = 4096;

  Duration heartbeatPeriod = const Duration(seconds: 10);
}
