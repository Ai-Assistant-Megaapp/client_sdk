import 'dart:convert';

class MessageModel {
  MessageModel({
    this.chatId,
    this.sender,
    this.text
  });

  MessageModel.fromJson(dynamic json) {
    chatId = json['chat_id'];
    sender = json['sender'];
    text = json['text'];
  }

  MessageModel.fromJsonString(String jsonString) {
    final jsonData = jsonDecode(jsonString);
    MessageModel.fromJson(jsonData);
  }

  String? chatId;
  String? sender;
  String? text;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['chat_id'] = chatId;
    map['sender'] = sender;
    map['text'] = text;
    return map;
  }

  String toJsonString() {
    final map = toJson();
    return jsonEncode(map);
  }
}
