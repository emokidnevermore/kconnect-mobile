/// Состояния BLoC для системы сообщений
///
/// Определяет все возможные состояния управления сообщениями и чатами,
/// включая статусы загрузки, WebSocket соединение, счетчики непрочитанных сообщений.
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/messenger_websocket_service.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';
import '../../../feed/domain/models/post.dart';

/// Статусы загрузки для операций с сообщениями
enum MessagesStatus { initial, loading, success, failure }

/// Состояние системы сообщений
///
/// Хранит текущее состояние чатов, сообщений, статусов загрузки
/// и информацию о WebSocket соединении.
class MessagesState extends Equatable {
  final MessagesStatus status;
  final List<Chat> chats;
  final List<Chat> filteredChats;
  final String? error;
  final WebSocketConnectionState wsConnectionState;
  final Map<int, List<Message>> chatMessages; // chatId -> messages
  final Map<int, MessagesStatus> chatMessageStatuses; // chatId -> loading status
  final int totalUnreadCount; // Total unread messages across all chats
  final Map<int, Set<int>> typingUsers; // chatId -> Set<userId> - users currently typing
  final Map<int, Set<int>> readMessageIds; // chatId -> Set<messageId> - messages read by current user
  final Map<int, bool> chatHasMoreMessages; // chatId -> hasMore - whether there are more messages to load
  final Map<int, Post> cachedPosts; // postId -> Post - cache for posts displayed in messages
  final Map<int, String> postLoadErrors; // postId -> error message - errors for failed post loads

  const MessagesState({
    this.status = MessagesStatus.initial,
    this.chats = const [],
    this.filteredChats = const [],
    this.error,
    this.wsConnectionState = WebSocketConnectionState.disconnected,
    this.chatMessages = const {},
    this.chatMessageStatuses = const {},
    this.totalUnreadCount = 0,
    this.typingUsers = const {},
    this.readMessageIds = const {},
    this.chatHasMoreMessages = const {},
    this.cachedPosts = const {},
    this.postLoadErrors = const {},
  });

  MessagesState copyWith({
    MessagesStatus? status,
    List<Chat>? chats,
    List<Chat>? filteredChats,
    String? error,
    WebSocketConnectionState? wsConnectionState,
    Map<int, List<Message>>? chatMessages,
    Map<int, MessagesStatus>? chatMessageStatuses,
    int? totalUnreadCount,
    Map<int, Set<int>>? typingUsers,
    Map<int, Set<int>>? readMessageIds,
    Map<int, bool>? chatHasMoreMessages,
    Map<int, Post>? cachedPosts,
    Map<int, String>? postLoadErrors,
  }) {
    return MessagesState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      filteredChats: filteredChats ?? this.filteredChats,
      error: error ?? this.error,
      wsConnectionState: wsConnectionState ?? this.wsConnectionState,
      chatMessages: chatMessages ?? this.chatMessages,
      chatMessageStatuses: chatMessageStatuses ?? this.chatMessageStatuses,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      typingUsers: typingUsers ?? this.typingUsers,
      readMessageIds: readMessageIds ?? this.readMessageIds,
      chatHasMoreMessages: chatHasMoreMessages ?? this.chatHasMoreMessages,
      cachedPosts: cachedPosts ?? this.cachedPosts,
      postLoadErrors: postLoadErrors ?? this.postLoadErrors,
    );
  }

  @override
  List<Object?> get props => [
    status,
    chats,
    filteredChats,
    error,
    wsConnectionState,
    chatMessages,
    chatMessageStatuses,
    totalUnreadCount,
    typingUsers,
    readMessageIds,
    chatHasMoreMessages,
    cachedPosts,
    postLoadErrors,
  ];

  // Геттеры для удобного доступа к данным

  /// Получить сообщение по ID из чата
  Message? getMessage(int chatId, int? messageId) {
    final messages = chatMessages[chatId];
    if (messages == null || messageId == null) return null;
    try {
      return messages.firstWhere((m) => m.id == messageId);
    } catch (e) {
      return null;
    }
  }

  /// Получить список сообщений чата
  List<Message> getChatMessages(int chatId) {
    return chatMessages[chatId] ?? [];
  }

  /// Получить чат по ID
  Chat? getChat(int chatId) {
    try {
      return chats.firstWhere((c) => c.id == chatId);
    } catch (e) {
      return null;
    }
  }

  // Helper методы для иммутабельных обновлений

  /// Обновить сообщение в чате с помощью функции-обновлятеля
  MessagesState withUpdatedMessage(
    int chatId,
    int? messageId,
    Message Function(Message) updater,
  ) {
    final currentMessages = chatMessages[chatId];
    if (currentMessages == null || messageId == null) return this;

    final updatedMessages = currentMessages.map((message) {
      if (message.id == messageId) {
        return updater(message);
      }
      return message;
    }).toList();

    // Создаем новый Map с новой ссылкой на список
    final newChatMessages = Map<int, List<Message>>.from(chatMessages);
    newChatMessages[chatId] = updatedMessages;

    return copyWith(chatMessages: newChatMessages);
  }

  /// Обновить сообщение в чате по clientMessageId
  MessagesState withUpdatedMessageByClientId(
    int chatId,
    String clientMessageId,
    Message Function(Message) updater,
  ) {
    final currentMessages = chatMessages[chatId];
    if (currentMessages == null) return this;

    final updatedMessages = currentMessages.map((message) {
      if (message.clientMessageId == clientMessageId) {
        return updater(message);
      }
      return message;
    }).toList();

    // Создаем новый Map с новой ссылкой на список
    final newChatMessages = Map<int, List<Message>>.from(chatMessages);
    newChatMessages[chatId] = updatedMessages;

    return copyWith(chatMessages: newChatMessages);
  }

  /// Добавить новое сообщение в чат
  /// Проверяет дубликаты по id, clientMessageId и tempId
  MessagesState withNewMessage(
    int chatId,
    Message message, {
    bool incrementUnread = false,
  }) {
    final currentMessages = chatMessages[chatId] ?? [];
    
    // Проверка на дубликаты:
    // 1. По id (если сообщение уже имеет серверный id)
    // 2. По clientMessageId (если это временное сообщение)
    // 3. По tempId (если есть временный id)
    final isDuplicate = currentMessages.any((existingMessage) {
      // Проверка по id
      if (message.id != null && existingMessage.id == message.id) {
        return true;
      }
      // Проверка по clientMessageId
      if (message.clientMessageId != null && 
          existingMessage.clientMessageId == message.clientMessageId) {
        return true;
      }
      // Проверка по tempId
      if (message.tempId != null && 
          existingMessage.tempId == message.tempId) {
        return true;
      }
      return false;
    });

    // Если сообщение уже существует, не добавляем его снова
    if (isDuplicate) {
      debugPrint('MessagesState: Duplicate message detected, skipping. id: ${message.id}, clientMessageId: ${message.clientMessageId}, tempId: ${message.tempId}');
      return this;
    }

    // Добавляем в начало, так как сообщения отсортированы newest first
    final updatedMessages = [message, ...currentMessages];

    // Создаем новый Map
    final newChatMessages = Map<int, List<Message>>.from(chatMessages);
    newChatMessages[chatId] = updatedMessages;

    // Обновляем чат с новым последним сообщением
    return withUpdatedChat(
      chatId,
      (chat) => chat.copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
        unreadCount: incrementUnread ? chat.unreadCount + 1 : chat.unreadCount,
      ),
    ).copyWith(chatMessages: newChatMessages).withRecalculatedUnreadCounts();
  }

  /// Обновить чат с помощью функции-обновлятеля
  MessagesState withUpdatedChat(int chatId, Chat Function(Chat) updater) {
    final updatedChats = chats.map((chat) {
      if (chat.id == chatId) {
        return updater(chat);
      }
      return chat;
    }).toList();

    final updatedFilteredChats = filteredChats.map((chat) {
      if (chat.id == chatId) {
        return updater(chat);
      }
      return chat;
    }).toList();

    return copyWith(
      chats: updatedChats,
      filteredChats: updatedFilteredChats,
    );
  }

  /// Обновить статус сообщения
  MessagesState withMessageStatus(
    int chatId,
    int messageId,
    MessageDeliveryStatus status,
  ) {
    return withUpdatedMessage(
      chatId,
      messageId,
      (message) => message.copyWith(deliveryStatus: status),
    ).withUpdatedChat(
      chatId,
      (chat) {
        // Обновляем lastMessage если это оно
        if (chat.lastMessage?.id == messageId) {
          return chat.copyWith(
            lastMessage: chat.lastMessage!.copyWith(deliveryStatus: status),
          );
        }
        return chat;
      },
    );
  }

  /// Пересчитать счетчики непрочитанных сообщений
  MessagesState withRecalculatedUnreadCounts() {
    final newTotalUnread = chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
    return copyWith(totalUnreadCount: newTotalUnread);
  }

  /// Проверить, прочитано ли сообщение текущим пользователем
  bool isMessageRead(int chatId, int messageId) {
    final readIds = readMessageIds[chatId];
    return readIds != null && readIds.contains(messageId);
  }

  /// Добавить сообщение в список прочитанных
  MessagesState withMessageRead(int chatId, int messageId) {
    final currentReadIds = readMessageIds[chatId] ?? <int>{};
    if (currentReadIds.contains(messageId)) {
      // Уже прочитано, не обновляем
      return this;
    }

    final newReadIds = Set<int>.from(currentReadIds)..add(messageId);
    final newReadMessageIds = Map<int, Set<int>>.from(readMessageIds);
    newReadMessageIds[chatId] = newReadIds;

    return copyWith(readMessageIds: newReadMessageIds);
  }

  /// Добавить несколько сообщений в список прочитанных
  MessagesState withMessagesRead(int chatId, List<int> messageIds) {
    final currentReadIds = readMessageIds[chatId] ?? <int>{};
    final newReadIds = Set<int>.from(currentReadIds)..addAll(messageIds);
    
    final newReadMessageIds = Map<int, Set<int>>.from(readMessageIds);
    newReadMessageIds[chatId] = newReadIds;

    return copyWith(readMessageIds: newReadMessageIds);
  }

  /// Получить список непрочитанных сообщений в чате
  List<Message> getUnreadMessages(int chatId, {int? currentUserId}) {
    final messages = chatMessages[chatId] ?? [];
    final readIds = readMessageIds[chatId] ?? <int>{};
    
    return messages.where((message) {
      // Пропускаем сообщения от текущего пользователя
      if (currentUserId != null && message.senderId == currentUserId) {
        return false;
      }
      // Возвращаем только непрочитанные сообщения
      return message.id != null && !readIds.contains(message.id);
    }).toList();
  }

  /// Удалить сообщение из чата
  MessagesState withDeletedMessage(int chatId, int messageId) {
    final currentMessages = chatMessages[chatId];
    if (currentMessages == null) return this;

    final updatedMessages = currentMessages.where((m) => m.id != messageId).toList();

    final newChatMessages = Map<int, List<Message>>.from(chatMessages);
    if (updatedMessages.isEmpty) {
      newChatMessages.remove(chatId);
    } else {
      newChatMessages[chatId] = updatedMessages;
      // Обновляем lastMessage если удаленное было последним
      return withUpdatedChat(
        chatId,
        (chat) {
          if (chat.lastMessage?.id == messageId) {
            return chat.copyWith(lastMessage: updatedMessages.isNotEmpty ? updatedMessages.first : null);
          }
          return chat;
        },
      ).copyWith(chatMessages: newChatMessages);
    }

    return copyWith(chatMessages: newChatMessages);
  }

  /// Обновить список чатов
  MessagesState withChats(List<Chat> newChats) {
    final newTotalUnread = newChats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
    return copyWith(
      chats: newChats,
      filteredChats: newChats,
      totalUnreadCount: newTotalUnread,
    );
  }

  /// Обновить список сообщений чата
  MessagesState withChatMessages(int chatId, List<Message> messages) {
    final newChatMessages = Map<int, List<Message>>.from(chatMessages);
    newChatMessages[chatId] = messages;
    return copyWith(chatMessages: newChatMessages);
  }

  /// Обновить статус загрузки сообщений чата
  MessagesState withChatMessageStatus(int chatId, MessagesStatus messageStatus) {
    final newStatuses = Map<int, MessagesStatus>.from(chatMessageStatuses);
    newStatuses[chatId] = messageStatus;
    return copyWith(chatMessageStatuses: newStatuses);
  }

  /// Обновить набор печатающих пользователей
  MessagesState withTypingUsers(int chatId, Set<int> userIds) {
    final newTypingUsers = Map<int, Set<int>>.from(typingUsers);
    if (userIds.isEmpty) {
      newTypingUsers.remove(chatId);
    } else {
      newTypingUsers[chatId] = userIds;
    }
    return copyWith(typingUsers: newTypingUsers);
  }

  /// Добавить пользователя в список печатающих
  MessagesState withTypingUserAdded(int chatId, int userId) {
    final currentTypingUsers = typingUsers[chatId] ?? {};
    final newTypingUsers = Set<int>.from(currentTypingUsers)..add(userId);
    return withTypingUsers(chatId, newTypingUsers);
  }

  /// Удалить пользователя из списка печатающих
  MessagesState withTypingUserRemoved(int chatId, int userId) {
    final currentTypingUsers = typingUsers[chatId] ?? {};
    final newTypingUsers = Set<int>.from(currentTypingUsers)..remove(userId);
    return withTypingUsers(chatId, newTypingUsers);
  }

  /// Получить пост из кеша по ID
  Post? getCachedPost(int postId) {
    return cachedPosts[postId];
  }

  /// Проверить, есть ли пост в кеше
  bool isPostCached(int postId) {
    return cachedPosts.containsKey(postId);
  }

  /// Добавить пост в кеш
  MessagesState withCachedPost(Post post) {
    final newCachedPosts = Map<int, Post>.from(cachedPosts);
    newCachedPosts[post.id] = post;
    return copyWith(cachedPosts: newCachedPosts);
  }

  /// Удалить пост из кеша
  MessagesState withRemovedCachedPost(int postId) {
    if (!cachedPosts.containsKey(postId)) {
      return this;
    }
    final newCachedPosts = Map<int, Post>.from(cachedPosts);
    newCachedPosts.remove(postId);
    return copyWith(cachedPosts: newCachedPosts);
  }

  /// Очистить весь кеш постов
  MessagesState withClearedPostCache() {
    return copyWith(cachedPosts: const {});
  }
}
