part of "mocks.dart";

class ConnectionStartMock extends Mock implements ConnectionStart {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 10;

  // Message arguments
  @override
  int versionMajor = 0;
  @override
  int versionMinor = 0;
  @override
  Map<String, Object?>? serverProperties;
  @override
  String mechanisms = "";
  @override
  String locales = "";

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeUInt8(versionMajor)
      ..writeUInt8(versionMinor)
      ..writeFieldTable(serverProperties)
      ..writeLongString(mechanisms)
      ..writeLongString(locales);
  }
}

class ConnectionSecureMock extends Mock implements ConnectionSecure {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 20;

  // Message arguments
  @override
  String? challenge;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeLongString(challenge);
  }
}

class ConnectionTuneMock extends Mock implements ConnectionTune {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 30;

  // Message arguments
  @override
  int channelMax = 0;
  @override
  int frameMax = 0;
  @override
  int heartbeat = 0;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeUInt16(channelMax)
      ..writeUInt32(frameMax)
      ..writeUInt16(heartbeat);
  }
}

class ConnectionOpenOkMock extends Mock implements ConnectionOpenOk {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 41;
  @override
  String? reserved_1;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeShortString(reserved_1);
  }
}

class ConnectionCloseOkMock extends Mock implements ConnectionCloseOk {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 51;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId);
  }
}
