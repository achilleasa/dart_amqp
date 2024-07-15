import 'dart:typed_data';

class Uint64Converter {
  const Uint64Converter._();

  static Uint8List uint64ToUint8List(int value, [Endian endian = Endian.big]) {
    ByteData byteData = ByteData(8);
    setUint64(byteData, 0, value, endian);
    return byteData.buffer.asUint8List();
  }

  static void setUint64(ByteData byteData, int byteOffset, int value,
      [Endian endian = Endian.big]) {
    byteData.setUint32(byteOffset, value >> 32, endian);
    byteData.setUint32(byteOffset + 4, value & 0xFFFFFFFF, endian);
  }

  static int getUint64(ByteData byteData, int byteOffset,
      [Endian endian = Endian.big]) {
    int high = byteData.getUint32(byteOffset, endian);
    int low = byteData.getUint32(byteOffset + 4, endian);
    return (high << 32) | low;
  }
}
