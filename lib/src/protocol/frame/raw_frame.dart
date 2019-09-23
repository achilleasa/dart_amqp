part of dart_amqp.protocol;

class RawFrame {
  final FrameHeader header;
  final ByteData payload;

  RawFrame(this.header, this.payload);

//  String toString() {
//    return """
//RawFrame
//--------
//  header  : ${header.toString().replaceAll(new RegExp("\n"), "\n            ")}
//  payload : Len = ${payload.lengthInBytes}
//""";
//  }
}
