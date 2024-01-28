part of dart_amqp.protocol;

class TuningSettings {
  // The maximum number of channels to allow. A value of 0 indicates that there
  // is no channel limit.
  int maxChannels = 0;

  int maxFrameSize = 4096;

  // Clients may specify a heartbeatPeriod > 1 second to enable heartbeat
  // support if the remote AMQP server supports it.
  //
  // During handshake, the heartbeat period value will be adjusted to
  // min(client hb period, server hb period). In other words, clients may force
  // a lower heartbeat period but they are never allowed to increase it beyond
  // the value suggested by the remote server.
  Duration heartbeatPeriod = Duration.zero;

  // When a non-zero heartbeat period is negotiated with the remote server, a
  // [HeartbeatFailedException] will be raised if the server does not respond
  // to [maxMissedHeartbeats] consecutive heartbeat requests.
  int maxMissedHeartbeats = 3;

  TuningSettings({
    this.maxChannels = 0,
    this.maxFrameSize = 4096,
    this.heartbeatPeriod = Duration.zero,
    this.maxMissedHeartbeats = 3,
  });
}
