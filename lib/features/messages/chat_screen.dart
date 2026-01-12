import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_state.dart';
import 'package:kconnect_mobile/features/messages/domain/models/chat.dart';
import 'package:kconnect_mobile/features/messages/domain/models/chat_member.dart';
import 'package:kconnect_mobile/features/messages/domain/models/message.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_state.dart';
import 'package:kconnect_mobile/injection.dart';
import 'package:kconnect_mobile/services/messenger_websocket_service.dart';
import 'package:kconnect_mobile/core/widgets/app_background.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/chat_header.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/chat_message_list.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/chat_message_input.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/forward_message_dialog.dart';
import 'package:kconnect_mobile/features/messages/presentation/screens/media_viewer_screen.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/message_search_bar.dart';

/// Информация о статусе онлайн пользователя
class OnlineStatusInfo {
  final OnlineStatusType type;
  final int? value; // Для минут/часов/дней/участников группы

  OnlineStatusInfo({
    required this.type,
    this.value,
  });
}

/// Тип статуса онлайн
enum OnlineStatusType {
  online,      // В сети
  recent,      // Недавно (менее минуты)
  minutes,     // Минуты назад
  hours,       // Часы назад
  days,        // Дни назад
  longAgo,     // Давно
  group,       // Группа (количество участников)
}

/// Экран чата для отображения и отправки сообщений
///
/// Позволяет просматривать историю сообщений, отправлять новые сообщения,
/// отображать статус доставки и поддерживает групповые чаты.
/// Включает жесты для быстрого возврата к списку чатов.
class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  double _dragStartX = 0;
  bool _isDragging = false;
  
  // Debounce timer for read receipts
  Timer? _readReceiptDebounceTimer;
  final Set<int> _pendingReadReceipts = {}; // messageId -> pending
  
  // Flag to track if widget is disposed
  bool _isDisposed = false;
  
  // Reply to message
  Message? _replyToMessage;
  
  // Edit message
  Message? _editingMessage;
  
  // Search
  bool _isSearching = false;
  String _searchQuery = '';
  
  // Track previous message count to detect new messages
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Load messages for this chat
    context.read<MessagesBloc>().add(LoadChatMessagesEvent(widget.chat.id));

    // Optimistically update UI immediately if there are unread messages
    // Use addPostFrameCallback to ensure widgets are initialized
    if (widget.chat.unreadCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          // Update UI immediately for instant feedback
          context.read<MessagesBloc>().add(MarkChatAsReadOptimisticallyEvent(chatId: widget.chat.id));
        }
      });
      
      // Mark messages as read after loading (send read receipts)
      _markMessagesAsReadAfterLoad();
    }
    
    // Listen to scroll events to mark messages as read when they become visible
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    // Check if widget is disposed
    if (_isDisposed || !mounted) {
      return;
    }
    
    // Check if user is scrolling and mark visible messages as read
    if (!_scrollController.hasClients) return;
    
    // Get current state
    final messagesBloc = context.read<MessagesBloc>();
    final state = messagesBloc.state;
    final chatId = widget.chat.id;
    final messages = state.chatMessages[chatId] ?? [];
    
    if (messages.isEmpty) return;
    
    // Calculate which messages are visible
    // Since list is reversed, visible messages are at the end of the list
    // We'll mark messages that are likely visible (first 20 from the end)
    final visibleRange = 20; // Approximate number of visible messages
    final startIndex = messages.length > visibleRange ? messages.length - visibleRange : 0;
    
    // Get current user ID
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
    
    // Mark visible unread messages as read
    int markedCount = 0;
    for (int i = startIndex; i < messages.length; i++) {
      final message = messages[i];
      if (message.id != null &&
          message.senderId?.toString() != currentUserId?.toString() &&
          !state.isMessageRead(chatId, message.id!)) {
        _sendReadReceiptDebounced(message.id!, chatId, state);
        markedCount++;
      }
    }
    
    // Flush read receipts if any were queued (only if still mounted)
    if (markedCount > 0 && !_isDisposed && mounted) {
      _flushReadReceipts(chatId);
    }
  }

  void _markMessagesAsReadAfterLoad() {
    // Capture current state before async gap
    final chatId = widget.chat.id;
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;

    // Wait a bit for messages to load, then send read receipts
    Future.delayed(const Duration(milliseconds: 500), () {
      // Check if widget is still mounted before sending read receipts
      if (_isDisposed || !mounted) {
        debugPrint('📖 ChatScreen: Widget disposed, skipping read receipts');
        return;
      }
      
      try {
        final messagesBloc = locator<MessagesBloc>();
        final state = messagesBloc.state;
        final messages = state.chatMessages[chatId] ?? [];

        if (messages.isNotEmpty) {
          final wsService = locator<MessengerWebSocketService>();
          if (wsService.currentConnectionState == WebSocketConnectionState.connected) {
            
            // Send read receipt only for unread messages from other users (with debounce)
            int pendingCount = 0;
            for (final message in messages) {
              if (message.id != null && 
                  message.senderId?.toString() != currentUserId?.toString() &&
                  !state.isMessageRead(chatId, message.id!)) {
                // Add to debounced queue
                _sendReadReceiptDebounced(message.id!, chatId, state);
                pendingCount++;
              }
            }
            // Flush immediately for initial load (no need to wait)
            if (pendingCount > 0 && !_isDisposed && mounted) {
              // Optimistically update UI immediately
              final messagesBloc = locator<MessagesBloc>();
              final currentState = messagesBloc.state;
              final currentChat = currentState.getChat(chatId);
              if ((currentChat?.unreadCount ?? 0) > 0) {
                messagesBloc.add(MarkChatAsReadOptimisticallyEvent(chatId: chatId));
              }
              _flushReadReceipts(chatId);
              debugPrint('📖 ChatScreen: Queued read receipts for $pendingCount unread messages (total: ${messages.length})');
            }
          }
        }
      } catch (e) {
        debugPrint('❌ ChatScreen: Failed to mark messages as read: $e');
      }
    });
  }

  void _markNewMessagesAsRead(List<Message> messages, MessagesState state) {
    // Check if widget is still mounted before sending read receipts
    if (_isDisposed || !mounted) {
      return;
    }
    
    try {
      final chatId = widget.chat.id;
      final authState = context.read<AuthBloc>().state;
      final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
      
      if (currentUserId == null) return;

      final wsService = locator<MessengerWebSocketService>();
      if (wsService.currentConnectionState != WebSocketConnectionState.connected) {
        return;
      }

      // Mark all unread messages from other users as read (with debounce)
      int readCount = 0;
      for (final message in messages) {
        if (message.id != null && 
            message.senderId?.toString() != currentUserId.toString() &&
            !state.isMessageRead(chatId, message.id!)) {
          // Add to debounced queue
          _sendReadReceiptDebounced(message.id!, chatId, state);
          readCount++;
        }
      }
      
      // Flush immediately for new messages (only if still mounted)
      if (readCount > 0 && !_isDisposed && mounted) {
        // Optimistically update UI immediately
        final messagesBloc = locator<MessagesBloc>();
        final currentState = messagesBloc.state;
        final currentChat = currentState.getChat(chatId);
        if ((currentChat?.unreadCount ?? 0) > 0) {
          messagesBloc.add(MarkChatAsReadOptimisticallyEvent(chatId: chatId));
        }
        _flushReadReceipts(chatId);
      }
    } catch (e) {
      debugPrint('❌ ChatScreen: Failed to mark new messages as read: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Mark as disposed to prevent read receipts
    _readReceiptDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// Отправить read_receipt с debounce для оптимизации
  void _sendReadReceiptDebounced(int messageId, int chatId, MessagesState state) {
    // Check if widget is disposed
    if (_isDisposed || !mounted) {
      return;
    }
    
    // Проверяем, не было ли сообщение уже прочитано
    if (state.isMessageRead(chatId, messageId)) {
      return;
    }
    
    // Добавляем в очередь
    _pendingReadReceipts.add(messageId);
    
    // Отменяем предыдущий таймер
    _readReceiptDebounceTimer?.cancel();
    
    // Устанавливаем новый таймер (debounce 300ms)
    _readReceiptDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isDisposed && mounted) {
        _flushReadReceipts(chatId);
      }
    });
  }
  
  /// Отправить все накопленные read_receipt
  void _flushReadReceipts(int chatId) {
    // Check if widget is disposed
    if (_isDisposed || !mounted) {
      return;
    }
    
    if (_pendingReadReceipts.isEmpty) return;
    
    try {
      final wsService = locator<MessengerWebSocketService>();
      if (wsService.currentConnectionState == WebSocketConnectionState.connected) {
        final messageIds = List<int>.from(_pendingReadReceipts);
        _pendingReadReceipts.clear();
        
        // Отправляем каждый read_receipt (API не поддерживает батчинг)
        for (final messageId in messageIds) {
          wsService.sendReadReceipt(
            messageId: messageId,
            chatId: chatId,
          );
        }
        
        debugPrint('📖 ChatScreen: Sent ${messageIds.length} read receipts (debounced)');
      }
    } catch (e) {
      debugPrint('❌ ChatScreen: Failed to flush read receipts: $e');
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    
    // Handle edit message
    if (_editingMessage != null && _editingMessage!.id != null) {
      if (content.isNotEmpty) {
        context.read<MessagesBloc>().add(EditMessageEvent(
          chatId: widget.chat.id,
          messageId: _editingMessage!.id!,
          content: content,
        ));
        _messageController.clear();
        setState(() {
          _editingMessage = null;
        });
      }
      return;
    }
    
    // Handle new message
    if (content.isNotEmpty || _replyToMessage != null) {
      context.read<MessagesBloc>().add(SendMessageEvent(
        chatId: widget.chat.id,
        content: content.isNotEmpty ? content : ' ',
        replyToId: _replyToMessage?.id,
      ));
      _messageController.clear();
      setState(() {
        _replyToMessage = null;
      });

      // Scroll to new messages after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToNewMessages();
      });
    }
  }
  
  void _setReplyToMessage(Message message) {
    setState(() {
      _replyToMessage = message;
    });
    // Focus text field
    FocusScope.of(context).requestFocus(FocusNode());
  }
  
  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }
  
  void _editMessage(Message message) {
    setState(() {
      _editingMessage = message;
      _replyToMessage = null; // Cancel reply if editing
      _messageController.text = message.content;
    });
    // Focus text field
    FocusScope.of(context).requestFocus(FocusNode());
  }
  
  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }
  
  void _deleteMessage(Message message) {
    if (message.id == null) return;
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<MessagesBloc>().add(DeleteMessageEvent(
                chatId: widget.chat.id,
                messageId: message.id!,
              ));
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _forwardMessage(Message message) {
    if (message.id == null) return;
    
    showDialog(
      context: context,
      builder: (context) => ForwardMessageDialog(
        messageId: message.id!,
        fromChatId: widget.chat.id,
      ),
    );
  }
  
  void _openMedia(Message message) {
    final photoUrl = message.photoUrl;
    final videoUrl = message.videoUrl;
    
    if (photoUrl != null || videoUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            photoUrl: photoUrl != null 
                ? (photoUrl.startsWith('http') ? photoUrl : 'https://k-connect.ru$photoUrl')
                : null,
            videoUrl: videoUrl != null
                ? (videoUrl.startsWith('http') ? videoUrl : 'https://k-connect.ru$videoUrl')
                : null,
          ),
        ),
      );
    }
  }
  
  void _navigateToMessage(int messageId) {
    if (!_scrollController.hasClients) return;
    
    // Find message index in the list
    final state = context.read<MessagesBloc>().state;
    final messages = state.chatMessages[widget.chat.id] ?? [];
    final messageIndex = messages.indexWhere((m) => m.id == messageId);
    
    if (messageIndex == -1) {
      debugPrint('ChatScreen: Message $messageId not found in chat');
      return;
    }
    
    // Calculate scroll position (with reverse: true, we need to scroll from bottom)
    // Each message is approximately 100 pixels, plus date dividers
    final itemHeight = 100.0;
    
    // Since list is reversed, position from top is (totalMessages - index - 1) * itemHeight
    final reversedIndex = messages.length - messageIndex - 1;
    final targetOffset = reversedIndex * itemHeight;
    
    // Scroll to message with animation
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    
    debugPrint('ChatScreen: Scrolling to message $messageId at index $messageIndex');
  }

  void _scrollToNewMessages() {
    if (_scrollController.hasClients) {
      // With reverse: true, new messages are at the top (minScrollExtent = 0)
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final currentX = details.globalPosition.dx;
    final deltaX = currentX - _dragStartX;

    // If dragging right with sufficient distance, dismiss
    if (deltaX > 70) { // 70px threshold - easier to trigger
      _isDragging = false;
      Navigator.of(context).pop();
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
  }

  bool _isSomeoneTyping(MessagesState state) {
    final typingUsers = state.typingUsers[widget.chat.id] ?? {};
    if (typingUsers.isEmpty) return false;
    
    // Get current user ID to exclude self
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;
    
    // Check if anyone except current user is typing
    return typingUsers.any((userId) => userId != currentUserId);
  }

  OnlineStatusInfo _getOnlineStatus(MessagesState state) {
    if (widget.chat.isGroup) {
      return OnlineStatusInfo(
        type: OnlineStatusType.group,
        value: widget.chat.members.length,
      );
    }
    
    // Find other member (not current user)
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
    
    if (widget.chat.members.isEmpty) {
      return OnlineStatusInfo(
        type: OnlineStatusType.recent,
      );
    }
    
    ChatMember? otherMember;
    try {
      otherMember = widget.chat.members.firstWhere(
        (member) => member.userId.toString() != currentUserId?.toString(),
      );
    } catch (e) {
      // If no other member found, use first member
      otherMember = widget.chat.members.first;
    }
    
    if (otherMember.isOnline) {
      return OnlineStatusInfo(
        type: OnlineStatusType.online,
      );
    }
    
    final now = DateTime.now();
    final lastActive = otherMember.lastActive;
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 1) {
      return OnlineStatusInfo(
        type: OnlineStatusType.recent,
      );
    } else if (difference.inMinutes < 60) {
      return OnlineStatusInfo(
        type: OnlineStatusType.minutes,
        value: difference.inMinutes,
      );
    } else if (difference.inHours < 24) {
      return OnlineStatusInfo(
        type: OnlineStatusType.hours,
        value: difference.inHours,
      );
    } else if (difference.inDays < 7) {
      return OnlineStatusInfo(
        type: OnlineStatusType.days,
        value: difference.inDays,
      );
    } else {
      return OnlineStatusInfo(
        type: OnlineStatusType.longAgo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MessagesBloc, MessagesState>(
      // Listen to unreadCount changes for this chat
      listenWhen: (previous, current) {
        final chatId = widget.chat.id;
        final prevChat = previous.getChat(chatId);
        final currChat = current.getChat(chatId);
        return prevChat?.unreadCount != currChat?.unreadCount;
      },
      listener: (context, state) {
        // When unreadCount changes and chat is open, mark messages as read
        if (_isDisposed || !mounted) return;
        
        final chatId = widget.chat.id;
        final currentChat = state.getChat(chatId);
        
        // If unreadCount increased (new message arrived), mark it as read immediately
        if (currentChat != null && currentChat.unreadCount > 0) {
          final messages = state.chatMessages[chatId] ?? [];
          _markAllUnreadMessagesAsRead(messages, state);
        }
      },
      child: BlocSelector<MessagesBloc, MessagesState, Map<String, dynamic>>(
          selector: (state) => {
            'messages': state.chatMessages[widget.chat.id] ?? [],
            'isLoading': state.chatMessageStatuses[widget.chat.id] == MessagesStatus.loading,
            'hasMoreMessages': state.chatHasMoreMessages[widget.chat.id] ?? false,
            'isLoadingMore': state.chatMessageStatuses[widget.chat.id] == MessagesStatus.loading && (state.chatMessages[widget.chat.id]?.isNotEmpty ?? false),
          },
          builder: (context, data) {
            final messages = data['messages'] as List<Message>;
            final isLoading = data['isLoading'] as bool;
            final hasMoreMessages = data['hasMoreMessages'] as bool;
            final isLoadingMore = data['isLoadingMore'] as bool;
            
            // Detect new messages and mark them as read (only if widget is still mounted)
            if (!_isDisposed && mounted && messages.length > _previousMessageCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_isDisposed && mounted) {
                  _markNewMessagesAsRead(messages, context.read<MessagesBloc>().state);
                }
              });
            }
            _previousMessageCount = messages.length;

          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
            fit: StackFit.expand,
            children: [
              // AppBackground для всего экрана
              AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),
              // Main content - занимает всё пространство, включая область под хедером и инпутом
              SafeArea(
                bottom: true,
                child: GestureDetector(
                  onHorizontalDragStart: _handleHorizontalDragStart,
                  onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  child: ChatMessageList(
                    chat: widget.chat,
                    messages: messages,
                    isLoading: isLoading,
                    scrollController: _scrollController,
                    onMessageLongPress: _setReplyToMessage,
                    onMessageEdit: _editMessage,
                    onMessageDelete: _deleteMessage,
                    onMessageForward: _forwardMessage,
                    onMessageOpenMedia: _openMedia,
                    onReplyTap: _navigateToMessage,
                    hasMoreMessages: hasMoreMessages,
                    isLoadingMore: isLoadingMore,
                    onLoadMore: () {
                      context.read<MessagesBloc>().add(LoadMoreChatMessagesEvent(widget.chat.id));
                    },
                    searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
                  ),
                ),
              ),
              // Custom header - overlay поверх контента
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: BlocBuilder<MessagesBloc, MessagesState>(
                          buildWhen: (previous, current) =>
                              previous.typingUsers[widget.chat.id] != current.typingUsers[widget.chat.id] ||
                              previous.chats.any((c) => c.id == widget.chat.id && c.members != widget.chat.members),
                          builder: (context, messagesState) => ChatHeader(
                            chat: widget.chat,
                            onlineStatus: _getOnlineStatus(messagesState),
                            isTyping: _isSomeoneTyping(messagesState),
                            onSearchTap: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchQuery = '';
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      if (_isSearching)
                        MessageSearchBar(
                          onSearchChanged: (query) {
                            setState(() {
                              _searchQuery = query;
                            });
                          },
                          onClose: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              // Message input - overlay поверх контента, вне AppBackground
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Material(
                    color: Colors.transparent,
                    child: ChatMessageInput(
                      controller: _messageController,
                      onSend: _sendMessage,
                      chatId: widget.chat.id,
                      replyToMessage: _replyToMessage,
                      onCancelReply: _cancelReply,
                      editingMessage: _editingMessage,
                      onCancelEdit: _cancelEdit,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
        },
      ),
    );
  }

  /// Пометить все непрочитанные сообщения как прочитанные для открытого чата
  void _markAllUnreadMessagesAsRead(List<Message> messages, MessagesState state) {
    if (_isDisposed || !mounted) return;
    
    try {
      final chatId = widget.chat.id;
      final authState = context.read<AuthBloc>().state;
      final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
      
      if (currentUserId == null) return;

      // First, optimistically update UI IMMEDIATELY to remove badges
      final messagesBloc = context.read<MessagesBloc>();
      final currentChat = state.getChat(chatId);
      
      if (currentChat != null && currentChat.unreadCount > 0) {
        messagesBloc.add(MarkChatAsReadOptimisticallyEvent(chatId: chatId));
        debugPrint('📖 ChatScreen: Optimistically updated unread count from ${currentChat.unreadCount} to 0 (new message arrived)');
      }

      // Then send read receipts for all unread messages from other users
      final wsService = locator<MessengerWebSocketService>();
      if (wsService.currentConnectionState == WebSocketConnectionState.connected) {
        int readCount = 0;
        for (final message in messages) {
          if (message.id != null && 
              message.senderId?.toString() != currentUserId.toString() &&
              !state.isMessageRead(chatId, message.id!)) {
            // Add to debounced queue
            _sendReadReceiptDebounced(message.id!, chatId, state);
            readCount++;
          }
        }
        
        // Flush receipts immediately if there are any
        if (readCount > 0 && !_isDisposed && mounted) {
          _flushReadReceipts(chatId);
          debugPrint('📖 ChatScreen: Sent read receipts for $readCount messages (chat is open)');
        }
      }
    } catch (e) {
      debugPrint('❌ ChatScreen: Failed to mark all unread messages as read: $e');
    }
  }
}
