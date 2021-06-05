part of dart_amqp.protocol;

class RawFrame {
  final FrameHeader header;
  final ByteData payload;

  RawFrame(this.header, this.payload);
}
