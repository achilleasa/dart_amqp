// The file contains all method messages for AMQP class Confirm (id: 85)
//
// File was *manually* generated at 2021-09-28 as the Confirm class is not
// included in the XML bindings spec.

// ignore_for_file: empty_constructor_bodies

part of dart_amqp.protocol;

class ConfirmSelect implements Message {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 85;
  @override
  final int msgMethodId = 10;

  // Message arguments
  bool noWait = false;

  ConfirmSelect();

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeBits([noWait]);
  }
}

class ConfirmSelectOk implements Message {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 85;
  @override
  final int msgMethodId = 11;

  ConfirmSelectOk();

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId);
  }
}
