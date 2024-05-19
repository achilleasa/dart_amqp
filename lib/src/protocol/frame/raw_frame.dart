part of "../../protocol.dart";

class RawFrame {
  final FrameHeader header;
  final ByteData payload;

  RawFrame(this.header, this.payload);
}
