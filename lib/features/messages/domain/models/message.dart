import 'package:equatable/equatable.dart';

/// Типы сообщений в чате
enum MessageType {
  /// Текстовое сообщение
  text,

  /// Сообщение с изображением (legacy, используйте photo)
  image,

  /// Сообщение с фото
  photo,

  /// Сообщение с видео
  video,

  /// Сообщение со стикером
  sticker,

  /// Сообщение с аудио
  audio,
}

/// Статус доставки сообщения
enum MessageDeliveryStatus {
  /// Сообщение отправляется
  sending,

  /// Сообщение отправлено
  sent,

  /// Сообщение доставлено
  delivered,

  /// Сообщение прочитано
  read,

  /// Ошибка отправки сообщения
  failed,
}

/// Модель данных сообщения в чате
///
/// Представляет сообщение со всей необходимой информацией
/// об отправителе, содержимом и статусе доставки.
class Message extends Equatable {
  final int? id;
  final int? senderId;
  final String? senderName;
  final String? senderUsername;
  final MessageType messageType;
  final String content;
  final DateTime createdAt;
  final String? clientMessageId;
  final String? tempId;
  final MessageDeliveryStatus deliveryStatus;
  final String? deviceId;
  final String? photoUrl;
  final String? videoUrl;
  final String? audioUrl;
  final int? fileSize;
  final String? mimeType;
  final int? replyToId;
  final DateTime? editedAt;
  final int? forwardedFromId;

  const Message({
    this.id,
    this.senderId,
    this.senderName,
    this.senderUsername,
    required this.messageType,
    required this.content,
    required this.createdAt,
    this.clientMessageId,
    this.tempId,
    this.deliveryStatus = MessageDeliveryStatus.sent,
    this.deviceId,
    this.photoUrl,
    this.videoUrl,
    this.audioUrl,
    this.fileSize,
    this.mimeType,
    this.replyToId,
    this.editedAt,
    this.forwardedFromId,
  });

  /// Парсинг типа сообщения из строки API
  /// Обрабатывает как новые типы (photo, sticker, audio), так и legacy (image)
  static MessageType _parseMessageType(String? messageTypeStr) {
    if (messageTypeStr == null) return MessageType.text;
    
    // Маппинг legacy типов
    if (messageTypeStr == 'image') {
      return MessageType.photo;
    }
    
    // Парсинг стандартных типов
    return MessageType.values.firstWhere(
      (type) => type.name == messageTypeStr,
      orElse: () => MessageType.text,
    );
  }

  /// Форматирование URL медиа-файлов согласно API
  /// Заменяет /api/ на /apiMes/ для доступа к файлам мессенджера
  static String? _formatMediaUrl(String? url) {
    if (url == null) return null;
    
    // Заменяем /api/ на /apiMes/ для доступа к файлам мессенджера
    if (url.contains('/api/messenger/files/')) {
      return url.replaceFirst('/api/', '/apiMes/');
    }
    
    return url;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    // Check is_read field (Int: 0 or 1) to determine read status
    final isRead = json['is_read'] as int? ?? 0;
    final readCount = json['read_count'] as int? ?? 0;
    
    // Determine delivery status
    MessageDeliveryStatus deliveryStatus;
    if (json['delivery_status'] != null) {
      // If delivery_status is explicitly provided, use it
      deliveryStatus = MessageDeliveryStatus.values.firstWhere(
        (status) => status.name == json['delivery_status'] as String?,
        orElse: () => MessageDeliveryStatus.sent,
      );
    } else {
      // Otherwise, determine from is_read field
      if (isRead > 0 || readCount > 0) {
        deliveryStatus = MessageDeliveryStatus.read;
      } else {
        deliveryStatus = MessageDeliveryStatus.sent;
      }
    }
    
    // Parse message type first
    MessageType messageType = _parseMessageType(json['message_type'] as String?);
    
    // Parse media URLs - try direct fields first
    String? photoUrl = _formatMediaUrl(json['photo_url'] as String?);
    String? videoUrl = _formatMediaUrl(json['video_url'] as String?);
    String? audioUrl = _formatMediaUrl(json['audio_url'] as String?);
    
    // If URLs are null but message type suggests media, try to construct URL from content
    // According to API: URL format is /apiMes/messenger/files/{chat_id}/{content}
    final content = json['content'] as String? ?? '';
    if (photoUrl == null && (messageType == MessageType.photo || messageType == MessageType.image)) {
      if (content.isNotEmpty && !content.startsWith('[') && !content.startsWith('http')) {
        // Content contains filename, construct URL path
        photoUrl = '/apiMes/messenger/files/${json['chat_id']}/$content';
      }
    }
    if (videoUrl == null && messageType == MessageType.video) {
      if (content.isNotEmpty && !content.startsWith('[') && !content.startsWith('http')) {
        // Content contains filename, construct URL path
        videoUrl = '/apiMes/messenger/files/${json['chat_id']}/$content';
      }
    }
    if (audioUrl == null && messageType == MessageType.audio) {
      if (content.isNotEmpty && !content.startsWith('[') && !content.startsWith('http')) {
        // Content contains filename, construct URL path
        audioUrl = '/apiMes/messenger/files/${json['chat_id']}/$content';
      }
    }
    
    // If message type is text but we have media URLs, correct the type
    if (messageType == MessageType.text) {
      if (photoUrl != null) {
        messageType = MessageType.photo;
      } else if (videoUrl != null) {
        messageType = MessageType.video;
      } else if (audioUrl != null) {
        messageType = MessageType.audio;
      }
    }
    
    return Message(
      id: json['id'] as int?,
      senderId: json['sender_id'] as int?,
      senderName: json['sender_name'] as String?,
      senderUsername: json['sender_username'] as String?,
      messageType: messageType,
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      clientMessageId: json['clientMessageId'] as String?,
      tempId: json['tempId'] as String?,
      deliveryStatus: deliveryStatus,
      deviceId: json['device_id'] as String?,
      photoUrl: photoUrl,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      replyToId: json['reply_to_id'] as int?,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String).toLocal()
          : null,
      forwardedFromId: json['forwarded_from_id'] as int?,
    );
  }

  factory Message.fromWebSocketMessage(Map<String, dynamic> wsData) {
    // Handle different WebSocket message formats
    // Format 1: message_sent response
    // Format 2: new_message response (has nested 'message' object)
    // Format 3: messages response (direct message object)
    
    final messageData = wsData['message'] as Map<String, dynamic>? ?? wsData;
    
    // Parse message type
    final messageTypeStr = messageData['message_type'] as String? ?? 'text';
    final messageType = _parseMessageType(messageTypeStr);

    // Parse timestamp - can be in different formats
    DateTime createdAt;
    if (messageData['timestamp'] != null) {
      try {
        createdAt = DateTime.parse(messageData['timestamp'] as String).toLocal();
      } catch (e) {
        createdAt = DateTime.now();
      }
    } else if (messageData['created_at'] != null) {
      try {
        createdAt = DateTime.parse(messageData['created_at'] as String).toLocal();
      } catch (e) {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    // Check is_read field (Int: 0 or 1) to determine read status
    final isRead = messageData['is_read'] as int? ?? 0;
    final readCount = messageData['read_count'] as int? ?? 0;
    
    // Determine delivery status
    MessageDeliveryStatus deliveryStatus;
    if (messageData['delivery_status'] != null) {
      deliveryStatus = MessageDeliveryStatus.values.firstWhere(
        (status) => status.name == messageData['delivery_status'] as String?,
        orElse: () => MessageDeliveryStatus.sent,
      );
    } else if (isRead > 0 || readCount > 0) {
      deliveryStatus = MessageDeliveryStatus.read;
    } else {
      deliveryStatus = MessageDeliveryStatus.sent;
    }
    
    return Message(
      id: messageData['id'] as int? ?? 
          messageData['messageId'] as int?,
      senderId: messageData['sender_id'] as int?,
      senderName: messageData['sender_name'] as String?,
      senderUsername: messageData['sender_username'] as String?,
      messageType: messageType,
      content: messageData['content'] as String? ?? '',
      createdAt: createdAt,
      clientMessageId: messageData['clientMessageId'] as String? ?? 
                      wsData['clientMessageId'] as String?,
      tempId: messageData['tempId'] as String? ?? 
              wsData['tempId'] as String?,
      deliveryStatus: deliveryStatus,
      deviceId: messageData['device_id'] as String? ?? 
                wsData['device_id'] as String?,
      photoUrl: _formatMediaUrl(messageData['photo_url'] as String?),
      videoUrl: _formatMediaUrl(messageData['video_url'] as String?),
      audioUrl: _formatMediaUrl(messageData['audio_url'] as String?),
      fileSize: messageData['file_size'] as int?,
      mimeType: messageData['mime_type'] as String?,
      replyToId: messageData['reply_to_id'] as int?,
      editedAt: messageData['edited_at'] != null
          ? DateTime.parse(messageData['edited_at'] as String).toLocal()
          : null,
      forwardedFromId: messageData['forwarded_from_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'message_type': messageType.name,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'clientMessageId': clientMessageId,
      'tempId': tempId,
      'delivery_status': deliveryStatus.name,
      'device_id': deviceId,
    };
  }

  Message copyWith({
    int? id,
    int? senderId,
    String? senderName,
    String? senderUsername,
    MessageType? messageType,
    String? content,
    DateTime? createdAt,
    String? clientMessageId,
    String? tempId,
    MessageDeliveryStatus? deliveryStatus,
    String? deviceId,
    String? photoUrl,
    String? videoUrl,
    String? audioUrl,
    int? fileSize,
    String? mimeType,
    int? replyToId,
    DateTime? editedAt,
    int? forwardedFromId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderUsername: senderUsername ?? this.senderUsername,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      tempId: tempId ?? this.tempId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deviceId: deviceId ?? this.deviceId,
      photoUrl: photoUrl ?? this.photoUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      replyToId: replyToId ?? this.replyToId,
      editedAt: editedAt ?? this.editedAt,
      forwardedFromId: forwardedFromId ?? this.forwardedFromId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        messageType,
        content,
        createdAt,
        deliveryStatus, // Критично для обнаружения изменений статуса
        clientMessageId,
        tempId,
        deviceId,
        editedAt,
        forwardedFromId,
        photoUrl,
        videoUrl,
        audioUrl,
        fileSize,
        mimeType,
        replyToId,
      ];
}
