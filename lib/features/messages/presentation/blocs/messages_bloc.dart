/// BLoC для управления сообщениями и чатами
///
/// Управляет состоянием системы сообщений, включая загрузку чатов,
/// отправку сообщений, WebSocket соединение и обработку входящих сообщений.
/// Интегрируется с WebSocket сервисом для реального времени.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/messenger_websocket_service.dart';
import '../../../../services/posts_service.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../auth/presentation/blocs/auth_state.dart';
import '../../domain/repositories/messages_repository.dart';
import '../../domain/usecases/fetch_chats_usecase.dart';
import '../../domain/models/message.dart';
import 'messages_event.dart';
import 'messages_state.dart';
import 'websocket_handlers/websocket_event_handler.dart';
import 'websocket_handlers/message_read_handler.dart';
import 'websocket_handlers/new_message_handler.dart';
import 'websocket_handlers/message_sent_handler.dart';
import 'websocket_handlers/chats_received_handler.dart';
import 'websocket_handlers/typing_indicator_handler.dart';
import 'websocket_handlers/message_deleted_handler.dart';
import 'websocket_handlers/delivery_confirmation_ack_handler.dart';
import 'websocket_handlers/unread_counts_handler.dart';
import 'websocket_handlers/messages_received_handler.dart';
import 'websocket_handlers/connected_handler.dart';
import 'websocket_handlers/error_handler.dart';
import 'websocket_handlers/read_receipt_response_handler.dart';
import 'websocket_handlers/user_status_handler.dart';
import 'websocket_handlers/connection_stats_handler.dart';
import 'websocket_handlers/message_edited_handler.dart';

/// BLoC класс для управления сообщениями и чатами
///
/// Обрабатывает все операции с сообщениями: загрузка чатов, отправка сообщений,
/// получение новых сообщений через WebSocket, управление статусом прочтения.
/// Поддерживает оффлайн режим с локальным хранением.
class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  // ignore: unused_field
  final FetchChatsUseCase _fetchChatsUseCase;
  // ignore: unused_field
  final AuthBloc _authBloc;
  final MessagesRepository _messagesRepository;
  final MessengerWebSocketService _webSocketService;

  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;
  StreamSubscription<WebSocketConnectionState>? _wsConnectionSubscription;

  MessagesBloc(
    this._fetchChatsUseCase,
    this._authBloc,
    this._messagesRepository,
    this._webSocketService,
  ) : super(const MessagesState()) {
    on<LoadChatsEvent>(_onLoadChats);
    on<RefreshChatsEvent>(_onRefreshChats);
    on<SearchChatsEvent>(_onSearchChats);
    on<InitMessagesEvent>(_onInitMessages);
    on<ConnectWebSocketEvent>(_onConnectWebSocket);
    on<DisconnectWebSocketEvent>(_onDisconnectWebSocket);
    on<WebSocketMessageReceivedEvent>(_onWebSocketMessageReceived);
    on<WebSocketConnectionChangedEvent>(_onWebSocketConnectionChanged);
    on<LoadChatMessagesEvent>(_onLoadChatMessages);
    on<LoadMoreChatMessagesEvent>(_onLoadMoreChatMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<SendMediaMessageEvent>(_onSendMediaMessage);
    on<SendMediaBase64Event>(_onSendMediaBase64);
    on<EditMessageEvent>(_onEditMessage);
    on<DeleteMessageEvent>(_onDeleteMessage);
    on<ForwardMessageEvent>(_onForwardMessage);
    on<CreateChatEvent>(_onCreateChat);
    on<CreateGroupChatEvent>(_onCreateGroupChat);
    on<UpdateMessageStatusEvent>(_onUpdateMessageStatus);
    on<MarkChatAsReadEvent>(_onMarkChatAsRead);
    on<MarkChatAsReadOptimisticallyEvent>(_onMarkChatAsReadOptimistically);
    on<LoadPostEvent>(_onLoadPost);
    on<ClearPostCacheEvent>(_onClearPostCache);

    // Listen to auth changes to reload chats when user changes
    // _authBloc.stream.listen(_onAuthStateChanged);
  }



  @override
  Future<void> close() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _webSocketService.disconnect();
    return super.close();
  }

  Future<void> _onLoadChats(
    LoadChatsEvent event,
    Emitter<MessagesState> emit,
  ) async {
    emit(state.copyWith(status: MessagesStatus.loading));

    try {
      // Send WebSocket request to get chats instead of HTTP API
      _webSocketService.sendGetChatsMessage();
      // The response will be handled by _onWebSocketMessageReceived -> _handleChatsReceived
    } catch (e) {
      emit(state.copyWith(
        status: MessagesStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshChats(
    RefreshChatsEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      emit(state.copyWith(status: MessagesStatus.loading));
      // Send WebSocket request to refresh chats
      _webSocketService.sendGetChatsMessage();
      // The response will be handled by _onWebSocketMessageReceived -> _handleChatsReceived
    } catch (e) {
      emit(state.copyWith(
        status: MessagesStatus.failure,
        error: e.toString(),
      ));
    }
  }

  void _onSearchChats(
    SearchChatsEvent event,
    Emitter<MessagesState> emit,
  ) {
    if (event.query.isEmpty) {
      emit(state.copyWith(filteredChats: state.chats));
    } else {
      final filtered = state.chats
          .where((chat) =>
              chat.title.toLowerCase().contains(event.query.toLowerCase()))
          .toList();
      emit(state.copyWith(filteredChats: filtered));
    }
  }

  Future<void> _onInitMessages(
    InitMessagesEvent event,
    Emitter<MessagesState> emit,
  ) async {
    emit(const MessagesState());
  }

  Future<void> _onConnectWebSocket(
    ConnectWebSocketEvent event,
    Emitter<MessagesState> emit,
  ) async {
    debugPrint('MessagesBloc: ConnectWebSocketEvent received');
    if (_wsConnectionSubscription != null) {
      debugPrint('MessagesBloc: WebSocket already connected, skipping');
      return;
    }

    debugPrint('MessagesBloc: Connecting to WebSocket...');
    await _webSocketService.connect();

    debugPrint('MessagesBloc: Setting up message subscriptions...');
    _wsMessageSubscription = _webSocketService.messages.listen(
      (wsMessage) {
        debugPrint('MessagesBloc: WebSocket message received: ${wsMessage.type}');
        add(WebSocketMessageReceivedEvent(wsMessage.data));
      },
    );

    _wsConnectionSubscription = _webSocketService.connectionState.listen(
      (connectionState) {
        debugPrint('MessagesBloc: WebSocket state changed: $connectionState');
        add(WebSocketConnectionChangedEvent(connectionState));
      },
    );
  }

  Future<void> _onDisconnectWebSocket(
    DisconnectWebSocketEvent event,
    Emitter<MessagesState> emit,
  ) async {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _wsMessageSubscription = null;
    _wsConnectionSubscription = null;
    _webSocketService.disconnect();
  }

  void _onWebSocketMessageReceived(
    WebSocketMessageReceivedEvent event,
    Emitter<MessagesState> emit,
  ) {
    final messageType = event.message['type'] as String?;
    if (messageType == null) {
      debugPrint('MessagesBloc: WebSocket message received without type');
      return;
    }

    final handler = _getHandler(messageType);
    if (handler != null) {
      final newState = handler.handle(state, event.message, _authBloc, _webSocketService);
      emit(newState);
    } else {
      debugPrint('MessagesBloc: No handler for message type: $messageType');
    }
  }

  /// Получить обработчик для типа WebSocket сообщения
  WebSocketEventHandler? _getHandler(String messageType) {
    switch (messageType) {
      case 'connected':
        return ConnectedHandler();
      case 'chats':
        return ChatsReceivedHandler();
      case 'messages':
        return MessagesReceivedHandler();
      case 'message_sent':
        return MessageSentHandler();
      case 'new_message':
        return NewMessageHandler();
      case 'message_read':
        return MessageReadHandler();
      case 'typing_indicator':
        return TypingIndicatorHandler(isStart: true);
      case 'typing_indicator_end':
        return TypingIndicatorHandler(isStart: false);
      case 'message_deleted':
        return MessageDeletedHandler();
      case 'message_edited':
        return MessageEditedHandler();
      case 'delivery_confirmation_ack':
        return DeliveryConfirmationAckHandler();
      case 'unread_counts':
        return UnreadCountsHandler();
      case 'error':
        return ErrorHandler();
      case 'pong':
      case 'ping':
        // Ping/Pong handled in WebSocket service
        return null;
      case 'read_receipt':
        // Read receipt is sent by client, no handler needed
        return null;
      case 'read_receipt_response':
        return ReadReceiptResponseHandler();
      case 'user_status':
        return UserStatusHandler();
      case 'connection_stats':
        return ConnectionStatsHandler();
      default:
        return null;
    }
  }

  void _onWebSocketConnectionChanged(
    WebSocketConnectionChangedEvent event,
    Emitter<MessagesState> emit,
  ) {
    emit(state.copyWith(wsConnectionState: event.state));
  }

  Future<void> _onLoadChatMessages(
    LoadChatMessagesEvent event,
    Emitter<MessagesState> emit,
  ) async {
    final chatId = event.chatId;

    emit(state.copyWith(
      chatMessageStatuses: {
        ...state.chatMessageStatuses,
        chatId: MessagesStatus.loading,
      },
    ));

    try {
      // Use WebSocket to load messages instead of HTTP API
      if (_webSocketService.isAuthenticated) {
        _webSocketService.sendGetMessagesMessage(
          chatId: chatId,
          limit: 50, // Load last 50 messages
          forceRefresh: false,
        );
        // Response will be handled by _handleMessagesReceived
      } else {
        // Fallback to HTTP if WebSocket is not authenticated
        debugPrint('MessagesBloc: WebSocket not authenticated, using HTTP fallback');
        final messages = await _messagesRepository.fetchMessages(
          chatId,
          beforeId: event.beforeId,
        );
        
        // Determine if there are more messages (if we got a full page)
        final hasMore = messages.length >= 50; // Assuming 50 is the page size
        
        final List<Message> updatedMessages = event.beforeId != null
            ? [...(state.chatMessages[chatId] ?? []), ...messages] // Append older messages
            : messages; // Replace with new messages
        
        emit(state.copyWith(
          chatMessages: {
            ...state.chatMessages,
            chatId: updatedMessages,
          },
          chatMessageStatuses: {
            ...state.chatMessageStatuses,
            chatId: MessagesStatus.success,
          },
          chatHasMoreMessages: {
            ...state.chatHasMoreMessages,
            chatId: hasMore,
          },
        ));
      }
    } catch (e) {
      debugPrint('MessagesBloc: Error loading messages: $e');
      emit(state.copyWith(
        chatMessageStatuses: {
          ...state.chatMessageStatuses,
          chatId: MessagesStatus.failure,
        },
      ));
    }
  }

  Future<void> _onLoadMoreChatMessages(
    LoadMoreChatMessagesEvent event,
    Emitter<MessagesState> emit,
  ) async {
    final chatId = event.chatId;
    final currentMessages = state.chatMessages[chatId] ?? [];
    final hasMore = state.chatHasMoreMessages[chatId] ?? false;

    // Check if there are more messages to load
    if (!hasMore || currentMessages.isEmpty) {
      debugPrint('MessagesBloc: No more messages to load for chat $chatId');
      return;
    }

    // Get the oldest message ID (last in the list since messages are sorted newest first)
    final oldestMessage = currentMessages.last;
    if (oldestMessage.id == null) {
      debugPrint('MessagesBloc: Cannot load more messages, oldest message has no ID');
      return;
    }

    emit(state.copyWith(
      chatMessageStatuses: {
        ...state.chatMessageStatuses,
        chatId: MessagesStatus.loading,
      },
    ));

    try {
      // Load more messages using before_id
      final messages = await _messagesRepository.fetchMessages(
        chatId,
        beforeId: oldestMessage.id,
      );

      // Determine if there are more messages
      final moreMessages = messages.length >= 50;

      // Append older messages to the end of the list
      final updatedMessages = [...currentMessages, ...messages];

      emit(state.copyWith(
        chatMessages: {
          ...state.chatMessages,
          chatId: updatedMessages,
        },
        chatMessageStatuses: {
          ...state.chatMessageStatuses,
          chatId: MessagesStatus.success,
        },
        chatHasMoreMessages: {
          ...state.chatHasMoreMessages,
          chatId: moreMessages,
        },
      ));

      debugPrint('MessagesBloc: Loaded ${messages.length} more messages for chat $chatId');
    } catch (e) {
      debugPrint('MessagesBloc: Error loading more messages: $e');
      emit(state.copyWith(
        chatMessageStatuses: {
          ...state.chatMessageStatuses,
          chatId: MessagesStatus.failure,
        },
      ));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<MessagesState> emit,
  ) async {
    final clientMessageId = 'client_${DateTime.now().millisecondsSinceEpoch}';
    
    // Get current user info from AuthBloc
    final authState = _authBloc.state;
    int? currentUserId;
    String? currentUserName;
    String? currentUserUsername;
    
    if (authState is AuthAuthenticated) {
      // Convert String id to int
      currentUserId = int.tryParse(authState.user.id);
      currentUserUsername = authState.user.username;
      // Use username as name if name is not available
      currentUserName = authState.user.username;
    }
    
    final tempMessage = Message(
      senderId: currentUserId,
      senderName: currentUserName,
      senderUsername: currentUserUsername,
      messageType: MessageType.text,
      content: event.content,
      createdAt: DateTime.now(),
      clientMessageId: clientMessageId,
      deliveryStatus: MessageDeliveryStatus.sending,
      replyToId: event.replyToId, // Include replyToId in temporary message
    );

    // Add temporary message to UI (at the beginning since sorted newest first)
    final currentMessages = state.chatMessages[event.chatId] ?? [];
    final updatedMessages = [tempMessage, ...currentMessages];

    // Update chat's last message and updatedAt
    final updatedChats = state.chats.map((chat) {
      if (chat.id == event.chatId) {
        return chat.copyWith(
          lastMessage: tempMessage,
          updatedAt: tempMessage.createdAt,
        );
      }
      return chat;
    }).toList();

    final updatedFilteredChats = state.filteredChats.map((chat) {
      if (chat.id == event.chatId) {
        return chat.copyWith(
          lastMessage: tempMessage,
          updatedAt: tempMessage.createdAt,
        );
      }
      return chat;
    }).toList();

    emit(state.copyWith(
      chats: updatedChats,
      filteredChats: updatedFilteredChats,
      chatMessages: {
        ...state.chatMessages,
        event.chatId: updatedMessages,
      },
    ));

    try {
      // Check if WebSocket is authenticated before sending
      if (!_webSocketService.isAuthenticated) {
        debugPrint('MessagesBloc: Cannot send message - WebSocket not authenticated');
        add(UpdateMessageStatusEvent(
          clientMessageId: clientMessageId,
          status: MessageDeliveryStatus.failed,
        ));
        return;
      }

      // Send via WebSocket with correct format
      _webSocketService.sendMessage(
        content: event.content,
        chatId: event.chatId,
        clientMessageId: clientMessageId,
        replyToId: event.replyToId,
      );

      // Update status to sent (will be updated via WebSocket response)
      add(UpdateMessageStatusEvent(
        clientMessageId: clientMessageId,
        status: MessageDeliveryStatus.sent,
      ));
    } catch (e) {
      debugPrint('MessagesBloc: Error sending message: $e');
      // Update status to failed
      add(UpdateMessageStatusEvent(
        clientMessageId: clientMessageId,
        status: MessageDeliveryStatus.failed,
      ));
    }
  }

  Future<void> _onCreateChat(
    CreateChatEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _messagesRepository.createChat(event.userId, encrypted: event.encrypted);
      // Reload chats to include the new chat
      add(LoadChatsEvent());
    } catch (e) {
      emit(state.copyWith(
        status: MessagesStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreateGroupChat(
    CreateGroupChatEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Creating group chat: ${event.title} with ${event.userIds.length} users');
      await _messagesRepository.createGroupChat(event.title, event.userIds);
      // Reload chats to include the new chat
      add(LoadChatsEvent());
    } catch (e) {
      debugPrint('MessagesBloc: Error creating group chat: $e');
      emit(state.copyWith(
        status: MessagesStatus.failure,
        error: 'Не удалось создать групповой чат: ${e.toString()}',
      ));
    }
  }

  void _onUpdateMessageStatus(
    UpdateMessageStatusEvent event,
    Emitter<MessagesState> emit,
  ) {
    // Update message status in all chat messages
    final updatedChatMessages = <int, List<Message>>{};

    state.chatMessages.forEach((chatId, messages) {
      final updatedMessages = messages.map((message) {
        if (message.clientMessageId == event.clientMessageId) {
          return message.copyWith(deliveryStatus: event.status);
        }
        return message;
      }).toList();

      updatedChatMessages[chatId] = updatedMessages;
    });

    emit(state.copyWith(chatMessages: updatedChatMessages));
  }

  Future<void> _onMarkChatAsRead(
    MarkChatAsReadEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Marking chat ${event.chatId} as read');
      final markedCount = await _messagesRepository.markChatAsRead(event.chatId);

      debugPrint('MessagesBloc: Marked $markedCount messages as read');

      // Update chat unread count to 0
      final updatedChats = state.chats.map((chat) {
        if (chat.id == event.chatId) {
          return chat.copyWith(unreadCount: 0);
        }
        return chat;
      }).toList();

      final updatedFilteredChats = state.filteredChats.map((chat) {
        if (chat.id == event.chatId) {
          return chat.copyWith(unreadCount: 0);
        }
        return chat;
      }).toList();

      // Recalculate total unread count
      final newTotalUnread = updatedChats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);

      debugPrint('MessagesBloc: Updated totalUnreadCount after marking read: $newTotalUnread');

      emit(state.copyWith(
        chats: updatedChats,
        filteredChats: updatedFilteredChats,
        totalUnreadCount: newTotalUnread,
      ));
    } catch (e) {
      debugPrint('MessagesBloc: Failed to mark chat as read: $e');
      // Don't emit error state, just log it
    }
  }

  /// Оптимистичное обновление состояния для моментального обновления UI
  /// Не делает HTTP запрос, только обновляет локальное состояние
  void _onMarkChatAsReadOptimistically(
    MarkChatAsReadOptimisticallyEvent event,
    Emitter<MessagesState> emit,
  ) {
    debugPrint('MessagesBloc: Optimistically marking chat ${event.chatId} as read');

    // Update chat unread count to 0 immediately
    final updatedChats = state.chats.map((chat) {
      if (chat.id == event.chatId) {
        return chat.copyWith(unreadCount: 0);
      }
      return chat;
    }).toList();

    final updatedFilteredChats = state.filteredChats.map((chat) {
      if (chat.id == event.chatId) {
        return chat.copyWith(unreadCount: 0);
      }
      return chat;
    }).toList();

    // Recalculate total unread count
    final newTotalUnread = updatedChats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);

    debugPrint('MessagesBloc: Optimistically updated totalUnreadCount: $newTotalUnread');

    emit(state.copyWith(
      chats: updatedChats,
      filteredChats: updatedFilteredChats,
      totalUnreadCount: newTotalUnread,
    ));
  }

  Future<void> _onSendMediaMessage(
    SendMediaMessageEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Uploading media file: ${event.filePath}');
      
      // Upload media file
      final message = await _messagesRepository.uploadMedia(
        chatId: event.chatId,
        filePath: event.filePath,
        messageType: event.messageType,
        replyToId: event.replyToId,
      );

      debugPrint('MessagesBloc: Media uploaded successfully, message ID: ${message.id}');

      // Add message to state
      emit(state.withNewMessage(
        event.chatId,
        message,
        incrementUnread: false, // Don't increment unread for own messages
      ));
    } catch (e) {
      debugPrint('MessagesBloc: Error uploading media: $e');
      emit(state.copyWith(
        error: 'Не удалось загрузить файл: ${e.toString()}',
      ));
    }
  }

  Future<void> _onSendMediaBase64(
    SendMediaBase64Event event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Uploading media via Base64: ${event.filename}');
      
      // Upload media file via Base64
      final message = await _messagesRepository.uploadMediaBase64(
        chatId: event.chatId,
        type: event.type,
        filename: event.filename,
        base64Data: event.base64Data,
        replyToId: event.replyToId,
      );

      debugPrint('MessagesBloc: Media uploaded successfully via Base64, message ID: ${message.id}');

      // Add message to state
      emit(state.withNewMessage(
        event.chatId,
        message,
        incrementUnread: false, // Don't increment unread for own messages
      ));
    } catch (e) {
      debugPrint('MessagesBloc: Error uploading media via Base64: $e');
      emit(state.copyWith(
        error: 'Не удалось загрузить файл: ${e.toString()}',
      ));
    }
  }

  Future<void> _onEditMessage(
    EditMessageEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Editing message ${event.messageId} in chat ${event.chatId}');
      
      // Edit message via REST API
      final updatedMessage = await _messagesRepository.editMessage(
        event.chatId,
        event.messageId,
        event.content,
      );

      debugPrint('MessagesBloc: Message edited successfully: ${updatedMessage.id}');

      // Update message in state
      final updatedChatMessages = <int, List<Message>>{};
      state.chatMessages.forEach((chatId, messages) {
        final updatedMessages = messages.map((message) {
          if (message.id == event.messageId) {
            return updatedMessage;
          }
          return message;
        }).toList();
        updatedChatMessages[chatId] = updatedMessages;
      });

      emit(state.copyWith(chatMessages: updatedChatMessages));
    } catch (e) {
      debugPrint('MessagesBloc: Error editing message: $e');
      emit(state.copyWith(
        error: 'Не удалось отредактировать сообщение: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleteMessage(
    DeleteMessageEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Deleting message ${event.messageId} from chat ${event.chatId}');
      
      // Delete message via REST API
      await _messagesRepository.deleteMessage(event.chatId, event.messageId);

      debugPrint('MessagesBloc: Message deleted successfully');

      // Remove message from state
      final updatedChatMessages = <int, List<Message>>{};
      state.chatMessages.forEach((chatId, messages) {
        final updatedMessages = messages.where((message) => message.id != event.messageId).toList();
        updatedChatMessages[chatId] = updatedMessages;
      });

      emit(state.copyWith(chatMessages: updatedChatMessages));
    } catch (e) {
      debugPrint('MessagesBloc: Error deleting message: $e');
      emit(state.copyWith(
        error: 'Не удалось удалить сообщение: ${e.toString()}',
      ));
    }
  }

  Future<void> _onForwardMessage(
    ForwardMessageEvent event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      debugPrint('MessagesBloc: Forwarding message ${event.messageId} from chat ${event.fromChatId} to chat ${event.toChatId}');

      // Get the message to forward
      final messages = state.chatMessages[event.fromChatId] ?? [];
      final messageToForward = messages.firstWhere((m) => m.id == event.messageId);

      if (messageToForward.id == null) {
        throw Exception('Message ID is null');
      }

      // Send forwarded message via WebSocket
      _webSocketService.sendMessage(
        chatId: event.toChatId,
        content: messageToForward.content,
        clientMessageId: 'forward_${DateTime.now().millisecondsSinceEpoch}',
        forwardedFromId: event.fromChatId, // Forward from the original chat
      );

      debugPrint('MessagesBloc: Message forwarded successfully');
    } catch (e) {
      debugPrint('MessagesBloc: Error forwarding message: $e');
      emit(state.copyWith(
        error: 'Не удалось переслать сообщение: ${e.toString()}',
      ));
    }
  }

  Future<void> _onLoadPost(
    LoadPostEvent event,
    Emitter<MessagesState> emit,
  ) async {
    // Check if post is already cached
    if (state.isPostCached(event.postId)) {
      debugPrint('MessagesBloc: Post ${event.postId} already cached, skipping load');
      return;
    }

    try {
      debugPrint('MessagesBloc: Loading post ${event.postId}');
      final postsService = PostsService();
      final post = await postsService.fetchPostById(event.postId);

      debugPrint('MessagesBloc: Post ${event.postId} loaded successfully');
      emit(state.withCachedPost(post));
    } catch (e) {
      debugPrint('MessagesBloc: Error loading post ${event.postId}: $e');
      // Save error for failed post loads
      final newPostLoadErrors = Map<int, String>.from(state.postLoadErrors);
      newPostLoadErrors[event.postId] = e.toString();
      emit(state.copyWith(postLoadErrors: newPostLoadErrors));
    }
  }

  void _onClearPostCache(
    ClearPostCacheEvent event,
    Emitter<MessagesState> emit,
  ) {
    debugPrint('MessagesBloc: Clearing post cache');
    emit(state.withClearedPostCache());
  }

  // Старые методы-обработчики удалены - теперь используются handlers в websocket_handlers/
}
