// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  chatId: json['chat_id'] as String,
  senderId: json['sender_id'] as String,
  content: json['content'] as String,
  mediaUrl: json['media_url'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chat_id': instance.chatId,
      'sender_id': instance.senderId,
      'content': instance.content,
      'media_url': instance.mediaUrl,
      'created_at': instance.createdAt.toIso8601String(),
    };
