part of dart_amqp.enums;

class FieldType extends Enum<int> {
  static const FieldType BOOLEAN = FieldType._(116);
  static const FieldType SHORT_SHORT_INT = FieldType._(98);
  static const FieldType SHORT_SHORT_UINT = FieldType._(66);
  static const FieldType SHORT_INT = FieldType._(85);
  static const FieldType SHORT_UINT = FieldType._(117);
  static const FieldType LONG_INT = FieldType._(73);
  static const FieldType LONG_UINT = FieldType._(105);
  static const FieldType LONG_LONG_INT = FieldType._(76);
  static const FieldType LONG_LONG_UINT = FieldType._(108);
  static const FieldType FLOAT = FieldType._(102);
  static const FieldType DOUBLE = FieldType._(100);
  static const FieldType DECIMAL = FieldType._(68);
  static const FieldType SHORT_STRING = FieldType._(115);
  static const FieldType LONG_STRING = FieldType._(83);
  static const FieldType FIELD_ARRAY = FieldType._(65);
  static const FieldType TIMESTAMP = FieldType._(84);
  static const FieldType FIELD_TABLE = FieldType._(70);
  static const FieldType VOID = FieldType._(86);

  const FieldType._(int value) : super(value);

  static FieldType valueOf(int value) {
    if (value == BOOLEAN.value) return BOOLEAN;
    if (value == SHORT_SHORT_INT.value) return SHORT_SHORT_INT;
    if (value == SHORT_SHORT_UINT.value) return SHORT_SHORT_UINT;
    if (value == SHORT_INT.value) return SHORT_INT;
    if (value == SHORT_UINT.value) return SHORT_UINT;
    if (value == LONG_INT.value) return LONG_INT;
    if (value == LONG_UINT.value) return LONG_UINT;
    if (value == LONG_LONG_INT.value) return LONG_LONG_INT;
    if (value == LONG_LONG_UINT.value) return LONG_LONG_UINT;
    if (value == FLOAT.value) return FLOAT;
    if (value == DOUBLE.value) return DOUBLE;
    if (value == DECIMAL.value) return DECIMAL;
    if (value == SHORT_STRING.value) return SHORT_STRING;
    if (value == LONG_STRING.value) return LONG_STRING;
    if (value == FIELD_ARRAY.value) return FIELD_ARRAY;
    if (value == TIMESTAMP.value) return TIMESTAMP;
    if (value == FIELD_TABLE.value) return FIELD_TABLE;
    if (value == VOID.value) return VOID;
    throw ArgumentError("Invalid field type value $value");
  }

  static String nameOf(FieldType value) {
    if (value == BOOLEAN) return "BOOLEAN";
    if (value == SHORT_SHORT_INT) return "SHORT_SHORT_INT";
    if (value == SHORT_SHORT_UINT) return "SHORT_SHORT_UINT";
    if (value == SHORT_INT) return "SHORT_INT";
    if (value == SHORT_UINT) return "SHORT_UINT";
    if (value == LONG_INT) return "LONG_INT";
    if (value == LONG_UINT) return "LONG_UINT";
    if (value == LONG_LONG_INT) return "LONG_LONG_INT";
    if (value == LONG_LONG_UINT) return "LONG_LONG_UINT";
    if (value == FLOAT) return "FLOAT";
    if (value == DOUBLE) return "DOUBLE";
    if (value == DECIMAL) return "DECIMAL";
    if (value == SHORT_STRING) return "SHORT_STRING";
    if (value == LONG_STRING) return "LONG_STRING";
    if (value == FIELD_ARRAY) return "FIELD_ARRAY";
    if (value == TIMESTAMP) return "TIMESTAMP";
    if (value == FIELD_TABLE) return "FIELD_TABLE";
    if (value == VOID) return "VOID";
    return null;
  }
}
