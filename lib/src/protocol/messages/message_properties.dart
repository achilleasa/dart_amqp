part of dart_amqp.protocol;

class MessageProperties {
  String contentType;
  String contentEncoding;
  Map<String, Object> headers;
  int deliveryMode;
  int priority;
  String corellationId;
  String replyTo;
  String expiration;
  String messageId;
  DateTime timestamp;
  String type;
  String userId;
  String appId;

  MessageProperties();

  MessageProperties.persistentMessage() {
    persistent = true;
  }

  /// Flag the message as persistent or transient based on the value of
  /// [isPersistent]
  set persistent(bool isPersistent) => deliveryMode = isPersistent ? 2 : 1;

//  String toString() {
//    StringBuffer sb = new StringBuffer("""
//Message Properties
//------------------
//""");
//
//    if (contentType != null) {
//      sb.write("content-type = ${contentType}\n");
//    }
//    if (contentEncoding != null) {
//      sb.write("content-encoding = ${contentEncoding}\n");
//    }
//    if (headers != null) {
//      sb.write("headers = ${headers}\n");
//    }
//    if (deliveryMode != null) {
//      sb.write("delivery-mode = ${deliveryMode}\n");
//    }
//    if (priority != null) {
//      sb.write("priority = ${priority}\n");
//    }
//    if (corellationId != null) {
//      sb.write("corellation-id = ${corellationId}\n");
//    }
//    if (replyTo != null) {
//      sb.write("reply-to = ${replyTo}\n");
//    }
//    if (expiration != null) {
//      sb.write("expiration = ${expiration}\n");
//    }
//    if (messageId != null) {
//      sb.write("message-id = ${messageId}\n");
//    }
//    if (timestamp != null) {
//      sb.write("timestamp = ${timestamp}\n");
//    }
//    if (type != null) {
//      sb.write("type = ${type}\n");
//    }
//    if (userId != null) {
//      sb.write("user-id = ${userId}\n");
//    }
//    if (appId != null) {
//      sb.write("app-id = ${appId}\n");
//    }
//
//    return sb.toString();
//  }
}
