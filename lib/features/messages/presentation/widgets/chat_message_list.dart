/// Виджет списка сообщений чата
///
/// Отображает список сообщений с поддержкой скролла и автоматической подгрузки
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_state.dart';
import 'package:kconnect_mobile/features/messages/domain/models/chat.dart';
import 'package:kconnect_mobile/features/messages/domain/models/message.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/message_context_menu.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/date_divider.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'message_bubble.dart';

/// Список сообщений чата с автоматической подгрузкой при скролле
class ChatMessageList extends StatefulWidget {
  final Chat chat;
  final List<Message> messages;
  final bool isLoading;
  final ScrollController scrollController;
  final Function(Message)? onMessageLongPress;
  final Function(Message)? onMessageEdit;
  final Function(Message)? onMessageDelete;
  final Function(Message)? onMessageForward;
  final Function(Message)? onMessageOpenMedia;
  final Function(int)? onReplyTap;
  final bool hasMoreMessages;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final String? searchQuery;

  const ChatMessageList({
    super.key,
    required this.chat,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    this.onMessageLongPress,
    this.onMessageEdit,
    this.onMessageDelete,
    this.onMessageForward,
    this.onMessageOpenMedia,
    this.onReplyTap,
    this.hasMoreMessages = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.searchQuery,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoadingMore != widget.isLoadingMore) {
      _isLoadingMore = widget.isLoadingMore;
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Проверяем, что скролл контроллер готов
    if (!widget.scrollController.hasClients) return;

    // Проверяем, нужно ли загружать еще сообщения
    final position = widget.scrollController.position;
    final threshold = 200.0; // Порог в пикселях от верха для начала загрузки

    // В reversed ListView: новые сообщения внизу (pixels близко к 0), старые сообщения вверху (pixels близко к maxScrollExtent)
    // Когда пользователь скроллит вверх к старым сообщениям, position.pixels УВЕЛИЧИВАЕТСЯ
    // Проверяем, находится ли пользователь близко к верху (старым сообщениям)
    final distanceFromTop = position.maxScrollExtent - position.pixels;

    // Если пользователь близко к верху (старым сообщениям) и есть еще сообщения для загрузки
    if (distanceFromTop <= threshold &&
        widget.hasMoreMessages &&
        !_isLoadingMore &&
        !widget.isLoadingMore) {
      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() {
    if (_isLoadingMore || !widget.hasMoreMessages || widget.onLoadMore == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    widget.onLoadMore!();

    // Сбрасываем флаг загрузки через небольшую задержку
    // Это позволит избежать множественных вызовов пока BLoC не обновит состояние
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.messages.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: context.dynamicPrimaryColor,
        ),
      );
    }

    if (widget.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет сообщений',
              style: AppTextStyles.body.copyWith(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    // Filter messages by search query if provided
    final filteredMessages = (widget.searchQuery != null && widget.searchQuery!.isNotEmpty)
        ? widget.messages.where((message) {
            final query = widget.searchQuery!.toLowerCase();
            return message.content.toLowerCase().contains(query) ||
                   (message.senderName?.toLowerCase().contains(query) ?? false);
          }).toList()
        : widget.messages;
    
    // Messages come sorted "newest first" from API
    // With reverse: true in ListView, they will display correctly:
    // - newest messages at bottom (near input field)
    // - oldest messages at top
    // Build list with date dividers
    // Since reverse: true, we add dividers AFTER each date group
    // so they appear ABOVE the messages when displayed
    final List<Widget> items = [];
    
    for (int i = 0; i < filteredMessages.length; i++) {
      final message = filteredMessages[i];
      
      // Skip empty messages
      if (message.content.isEmpty) {
        continue;
      }
      
      final messageDate = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      
      // Get current user ID from AuthBloc
      final authState = context.read<AuthBloc>().state;
      final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;

      // Compare senderId as strings to handle type mismatches
      final isCurrentUser = message.senderId?.toString() == currentUserId?.toString();

      items.add(MessageBubble(
        key: ValueKey('message_${message.id}_${message.deliveryStatus}'), // Key includes status to force rebuild on status change
        message: message,
        isCurrentUser: isCurrentUser,
        showSenderName: widget.chat.isGroup == true,
        chatId: widget.chat.id,
        onLongPress: () => _showContextMenu(context, message, isCurrentUser),
        onReplyTap: widget.onReplyTap,
        searchQuery: widget.searchQuery,
      ));
      
      // Add divider AFTER the last message of each date group
      // (with reverse: true, this will appear ABOVE the group)
      final isLastMessage = i == filteredMessages.length - 1;
      DateTime? nextMessageDate;
      
      if (!isLastMessage) {
        // Find next non-empty message
        for (int j = i + 1; j < filteredMessages.length; j++) {
          if (filteredMessages[j].content.isNotEmpty) {
            nextMessageDate = DateTime(
              filteredMessages[j].createdAt.year,
              filteredMessages[j].createdAt.month,
              filteredMessages[j].createdAt.day,
            );
            break;
          }
        }
      }
      
      // Add divider if this is the last message of its date group
      if (isLastMessage || (nextMessageDate != null && messageDate != nextMessageDate)) {
        items.add(DateDivider(date: message.createdAt));
      }
    }
    
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 72),
      reverse: true,
      itemCount: items.length + (widget.hasMoreMessages ? 1 : 0),
      itemBuilder: (context, index) {
        // Load more indicator at the top (when reverse: true, top is the end)
        if (widget.hasMoreMessages && index == items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: (_isLoadingMore || widget.isLoadingMore)
                  ? CircularProgressIndicator(
                      color: context.dynamicPrimaryColor,
                    )
                  : TextButton(
                      onPressed: widget.onLoadMore,
                      child: Text(
                        'Загрузить еще',
                        style: TextStyle(color: context.dynamicPrimaryColor),
                      ),
                    ),
            ),
          );
        }

        // Messages and date dividers
        // When reverse: true, ListView automatically reverses the display order
        // items are in order [newest, ..., oldest]
        // index 0 (displayed at bottom) = items[0] (newest)
        // index N (displayed at top) = items[N] (oldest)
        if (index < 0 || index >= items.length) {
          return const SizedBox.shrink();
        }
        return items[index];
      },
    );
  }

  void _showContextMenu(BuildContext context, Message message, bool isCurrentUser) {
    MessageContextMenu.show(
      context,
      message: message,
      isCurrentUser: isCurrentUser,
      onReply: (msg) => widget.onMessageLongPress?.call(msg),
      onEdit: widget.onMessageEdit,
      onDelete: widget.onMessageDelete,
      onForward: widget.onMessageForward,
      onOpenMedia: widget.onMessageOpenMedia,
    );
  }
}
