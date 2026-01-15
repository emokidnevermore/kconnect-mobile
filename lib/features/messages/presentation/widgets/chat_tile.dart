/// Виджет плитки чата для списка чатов
///
/// Отображает информацию о чате: аватар, название, последнее сообщение,
/// время и количество непрочитанных сообщений.
/// Поддерживает навигацию к экрану чата при нажатии.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/authorized_cached_network_image.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../services/storage_service.dart';
import '../../chat_screen.dart';
import '../blocs/messages_bloc.dart';
import '../blocs/messages_event.dart';
import '../blocs/messages_state.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../auth/presentation/blocs/auth_state.dart';

/// Виджет плитки чата
class ChatTile extends StatelessWidget {
  final Chat chat;

  const ChatTile({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final tileColor = hasBackground 
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7) 
            : Theme.of(context).colorScheme.surfaceContainerLow;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: BlocSelector<MessagesBloc, MessagesState, Chat>(
            selector: (state) {
              // Select the chat from state to ensure rebuilds when chat changes
              // BlocSelector automatically rebuilds only when the selected value changes
              // Chat objects are compared by equality, so unreadCount changes will trigger rebuild
              // Check both chats and filteredChats to ensure we get the updated chat
              try {
                // First try to find in filteredChats (which is what MessagesScreen uses)
                final updatedChat = state.filteredChats.firstWhere((c) => c.id == chat.id);
                return updatedChat;
              } catch (e) {
                // If not found in filteredChats, try chats
                try {
                  final updatedChat = state.chats.firstWhere((c) => c.id == chat.id);
                  return updatedChat;
                } catch (e2) {
                  // If chat not found in state, return original chat
                  // This handles edge cases during state updates
                  return chat;
                }
              }
            },
            builder: (context, currentChat) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
                  ),
                  child: currentChat.avatar != null && currentChat.avatar!.isNotEmpty
                      ? ClipOval(
                          child: AuthorizedCachedNetworkImage(
                            imageUrl: currentChat.avatar!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Icon(
                              Icons.person,
                              color: context.dynamicPrimaryColor,
                              size: 24,
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              color: context.dynamicPrimaryColor,
                              size: 24,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: context.dynamicPrimaryColor,
                          size: 24,
                        ),
                ),
                title: SizedBox(
                  height: 54, // User-set height
                  child: Stack(
                    children: [
                      // Main content row - only name and last message
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: name and last message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Name at top left - aligned to baseline
                                Baseline(
                                  baseline: 16.0,
                                  baselineType: TextBaseline.alphabetic,
                                  child: Text(
                                    currentChat.title,
                                    style: AppTextStyles.h3.copyWith(
                                      color: context.dynamicPrimaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Last message at bottom left - with proper width constraint
                                SizedBox(
                                  width: MediaQuery.of(context).size.width - 160, // Leave space for badge
                                  child: BlocSelector<MessagesBloc, MessagesState, Set<int>>(
                                    selector: (state) => state.typingUsers[currentChat.id] ?? {},
                                    builder: (context, typingUsers) {
                                      // Check if someone is typing
                                      if (typingUsers.isNotEmpty) {
                                        return _TypingIndicator();
                                      }
                                      
                                      // Show last message or "Нет сообщений"
                                      if (currentChat.lastMessage != null) {
                                        // Check if last message is from current user
                                        final authState = context.read<AuthBloc>().state;
                                        final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
                                        final isFromCurrentUser = currentChat.lastMessage!.senderId?.toString() == currentUserId?.toString();
                                        
                                        // Format message text based on type
                                        String messageText;
                                        if (currentChat.lastMessage!.messageType == MessageType.photo) {
                                          messageText = '📷 Фото';
                                        } else if (currentChat.lastMessage!.messageType == MessageType.video) {
                                          messageText = '🎥 Видео';
                                        } else if (currentChat.lastMessage!.messageType == MessageType.audio) {
                                          messageText = '🎵 Аудио';
                                        } else if (currentChat.lastMessage!.messageType == MessageType.sticker) {
                                          messageText = '🎴 Стикер';
                                        } else if (currentChat.lastMessage!.replyToId != null) {
                                          messageText = '↩️ ${currentChat.lastMessage!.content}';
                                        } else if (currentChat.lastMessage!.forwardedFromId != null) {
                                          messageText = '↪️ Переслано: ${currentChat.lastMessage!.content}';
                                        } else {
                                          messageText = currentChat.lastMessage!.content;
                                        }
                                        
                                        final displayText = isFromCurrentUser
                                            ? 'Вы: $messageText'
                                            : messageText;
                                        
                                        return Text(
                                          displayText,
                                          style: AppTextStyles.body.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                      
                                      return Text(
                                        'Нет сообщений',
                                        style: AppTextStyles.body.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Time positioned at top right of entire container
                      if (currentChat.lastMessage != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Baseline(
                            baseline: 16.0,
                            baselineType: TextBaseline.alphabetic,
                            child: Text(
                              _formatChatTime(currentChat.lastMessage!.createdAt),
                              style: AppTextStyles.postTime.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      // Badge positioned at bottom right of entire container
                      if (currentChat.unreadCount > 0)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.dynamicPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              currentChat.unreadCount.toString(),
                              style: AppTextStyles.postTime.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                onTap: () async {
                  // Navigate to chat and wait for return
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(chat: currentChat),
                    ),
                  );
                  // Refresh chats list when returning from chat to get updated unread counts
                  if (context.mounted) {
                    context.read<MessagesBloc>().add(RefreshChatsEvent());
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  String _formatChatTime(DateTime messageTime) {
    final now = DateTime.now();
    final messageDate = DateTime(messageTime.year, messageTime.month, messageTime.day);
    final today = DateTime(now.year, now.month, now.day);

    // If message is from today, show time (HH:MM)
    if (messageDate == today) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    }
    // If message is older than 1 day, show date (DD.MM or DD.MM.YY)
    else {
      final yearsDiff = now.year - messageTime.year;
      if (yearsDiff == 0) {
        // Same year - show DD.MM
        return '${messageTime.day.toString().padLeft(2, '0')}.${messageTime.month.toString().padLeft(2, '0')}';
      } else {
        // Different year - show DD.MM.YY
        return '${messageTime.day.toString().padLeft(2, '0')}.${messageTime.month.toString().padLeft(2, '0')}.${(messageTime.year % 100).toString().padLeft(2, '0')}';
      }
    }
  }
}

/// Виджет индикатора печати с анимацией троеточия
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _controller.addListener(() {
      final value = _controller.value;
      final newDotCount = ((value * 3).floor() % 3) + 1;
      if (newDotCount != _dotCount) {
        setState(() {
          _dotCount = newDotCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Text(
      'Печатает$dots',
      style: AppTextStyles.body.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
