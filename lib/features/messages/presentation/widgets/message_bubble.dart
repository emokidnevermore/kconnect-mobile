/// Виджет пузырька сообщения
///
/// Отображает одно сообщение с временем и статусом доставки
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:kconnect_mobile/features/messages/domain/models/message.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_state.dart';
import 'package:kconnect_mobile/features/messages/presentation/screens/media_viewer_screen.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/message_post_card.dart';
import 'package:kconnect_mobile/features/feed/domain/models/post.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Пузырек сообщения
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final bool showSenderName;
  final int chatId;
  final VoidCallback? onLongPress;
  final Function(int)? onReplyTap; // messageId to navigate to
  final String? searchQuery; // Query to highlight in message

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.showSenderName,
    required     this.chatId,
    this.onLongPress,
    this.onReplyTap,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    // Use BlocSelector to select only the specific message from state
    // This ensures the widget rebuilds when the message object changes
    // Equatable in Message allows BlocSelector to detect changes by value
    return BlocSelector<MessagesBloc, MessagesState, Message>(
      selector: (state) => state.getMessage(chatId, message.id) ?? message,
      // buildWhen is not needed here because Equatable in Message will handle change detection
      // BlocSelector will only rebuild when the selected Message object changes (by value comparison)
      builder: (context, displayMessage) {
        return _buildMessageContent(context, displayMessage);
      },
    );
  }

  Widget _buildMessageContent(BuildContext context, Message displayMessage) {
    // Time and status row/column
    final timeWidget = isCurrentUser
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status icon first for current user
              _buildDeliveryStatus(context, displayMessage.deliveryStatus),
              const SizedBox(width: 4),
              // Then time
              Text(
                _formatTime(displayMessage.createdAt),
                style: AppTextStyles.postTime.copyWith(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              // Edited label
              if (displayMessage.editedAt != null) ...[
                const SizedBox(width: 4),
                Text(
                  '(изменено)',
                  style: AppTextStyles.postTime.copyWith(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(displayMessage.createdAt),
                style: AppTextStyles.postTime.copyWith(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              // Edited label
              if (displayMessage.editedAt != null) ...[
                const SizedBox(width: 4),
                Text(
                  '(изменено)',
                  style: AppTextStyles.postTime.copyWith(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          );

    // Message bubble
    // Calculate max width accounting for ListView padding (32px total) and timeWidget (~60px)
    final screenWidth = MediaQuery.of(context).size.width;
    final listViewPadding = 32.0; // 16px left + 16px right
    final timeWidgetWidth = 60.0; // Approximate width of time widget
    final spacing = 8.0; // SizedBox between bubble and time
    final maxBubbleWidth = screenWidth - listViewPadding - timeWidgetWidth - spacing;
    
    final messageBubble = Container(
      constraints: BoxConstraints(
        maxWidth: maxBubbleWidth * 0.95, // Leave small margin for safety
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? context.dynamicPrimaryColor.withValues(alpha: 0.3) // Lighter for own messages
            : context.dynamicPrimaryColor.withValues(alpha: 0.1), // Very transparent for others
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forward label if exists
          if (displayMessage.forwardedFromId != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forward,
                    size: 12,
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Переслано из другого чата',
                    style: TextStyle(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Show sender name for group chats (not for current user)
          if (showSenderName && !isCurrentUser && displayMessage.senderName != null) ...[
            Text(
              displayMessage.senderName!,
              style: AppTextStyles.body.copyWith(
                color: context.dynamicPrimaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Reply preview if exists
          if (displayMessage.replyToId != null) ...[
            _buildReplyPreview(context, displayMessage),
            const SizedBox(height: 8),
          ],
          // Message content - media or text
          // Check URLs first (more reliable than messageType alone)
          // This ensures media is displayed even if messageType is incorrectly set
          if (displayMessage.messageType == MessageType.sticker)
            _buildStickerMessage(context, displayMessage)
          else if (displayMessage.photoUrl != null)
            _buildPhotoMessage(context, displayMessage)
          else if (displayMessage.videoUrl != null)
            _buildVideoMessage(context, displayMessage)
          else if (displayMessage.audioUrl != null)
            _buildAudioMessage(context, displayMessage)
          else
            _buildMessageTextWithPostLinks(context, displayMessage.content, isCurrentUser),
        ],
      ),
    );

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: isCurrentUser ? [
          // For current user: time/status first, then message bubble
          timeWidget,
          const SizedBox(width: 8),
          Flexible(child: messageBubble),
        ] : [
          // For others: message bubble first, then time
          Flexible(child: messageBubble),
          const SizedBox(width: 8),
          timeWidget,
        ],
      ),
    );
    
    // Wrap with GestureDetector for long press
    if (onLongPress != null) {
      return GestureDetector(
        onLongPress: onLongPress,
        child: content,
      );
    }
    
    return content;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildDeliveryStatus(BuildContext context, MessageDeliveryStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageDeliveryStatus.sending:
        icon = Icons.access_time;
        color = context.dynamicPrimaryColor.withValues(alpha: 0.5);
        break;
      case MessageDeliveryStatus.sent:
        icon = Icons.check;
        color = context.dynamicPrimaryColor.withValues(alpha: 0.7);
        break;
      case MessageDeliveryStatus.delivered:
        // One check mark for delivered
        icon = Icons.check;
        color = context.dynamicPrimaryColor;
        break;
      case MessageDeliveryStatus.failed:
        icon = Icons.warning;
        color = Theme.of(context).colorScheme.error;
        break;
      case MessageDeliveryStatus.read:
        // Double check for read status - use Stack to overlap icons
        return SizedBox(
          width: 18, // Width to accommodate two overlapping icons
          height: 14,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: context.dynamicPrimaryColor,
                ),
              ),
              Positioned(
                left: 4, // Overlap by 4 pixels
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: context.dynamicPrimaryColor,
                ),
              ),
            ],
          ),
        );
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }

  Widget _buildPhotoMessage(BuildContext context, Message message) {
    // Try to get photoUrl - if null, construct from content
    String? photoUrl = message.photoUrl;
    if (photoUrl == null && message.content.isNotEmpty && !message.content.startsWith('[') && !message.content.startsWith('http')) {
      // Construct URL from content: /apiMes/messenger/files/{chat_id}/{content}
      photoUrl = '/apiMes/messenger/files/$chatId/${message.content}';
    }
    final fullPhotoUrl = _getFullMediaUrl(photoUrl);
    if (fullPhotoUrl == null) {
      return Text(
        message.content,
        style: AppTextStyles.body.copyWith(
          color: context.dynamicPrimaryColor,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaViewerScreen(photoUrl: fullPhotoUrl),
            ),
          );
        },
        child: AuthorizedCachedNetworkImage(
          imageUrl: fullPhotoUrl,
          width: MediaQuery.of(context).size.width * 0.6,
          fit: BoxFit.cover,
          memCacheWidth: 500, // Optimize memory usage for large images
          memCacheHeight: 500,
          placeholder: (context, url) => Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: 200,
            color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
            child: Center(
              child: CircularProgressIndicator(
                color: context.dynamicPrimaryColor,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: 200,
            color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
            child: Icon(
              Icons.broken_image,
              color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, Message message) {
    // Try to get videoUrl - if null, construct from content
    String? videoUrl = message.videoUrl;
    if (videoUrl == null && message.content.isNotEmpty && !message.content.startsWith('[') && !message.content.startsWith('http')) {
      // Construct URL from content: /apiMes/messenger/files/{chat_id}/{content}
      videoUrl = '/apiMes/messenger/files/$chatId/${message.content}';
    }
    final fullVideoUrl = _getFullMediaUrl(videoUrl);
    if (fullVideoUrl == null) {
      return Text(
        message.content,
        style: AppTextStyles.body.copyWith(
          color: context.dynamicPrimaryColor,
        ),
      );
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      height: 200,
      decoration: BoxDecoration(
        color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video thumbnail placeholder
          Icon(
            Icons.videocam,
            size: 48,
            color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
          ),
          // Play button overlay
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaViewerScreen(videoUrl: fullVideoUrl),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerMessage(BuildContext context, Message message) {
    // Stickers can be stored in photoUrl or constructed from sticker_data
    // Format: content is like "[STICKER_1_2]" where 1 is pack_id and 2 is sticker_id
    // For now, stickers may come with photoUrl or we need to construct URL from content
    String? stickerUrl;
    
    if (message.photoUrl != null && message.photoUrl!.isNotEmpty) {
      stickerUrl = _getFullMediaUrl(message.photoUrl);
    } else if (message.content.startsWith('[STICKER_')) {
      // Construct sticker URL from content format: [STICKER_packId_stickerId]
      // TODO: Implement proper sticker URL construction from API
      // For now, use placeholder
      stickerUrl = null;
    }
    
    if (stickerUrl == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '🎴 Стикер',
          style: AppTextStyles.body.copyWith(
            color: context.dynamicPrimaryColor,
          ),
        ),
      );
    }

    // Stickers are usually square images (256x256 or 512x512)
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () {
          // Open sticker in full screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaViewerScreen(photoUrl: stickerUrl),
            ),
          );
        },
        child: AuthorizedCachedNetworkImage(
          imageUrl: stickerUrl,
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          memCacheWidth: 256, // Stickers are usually 256x256 or 512x512
          memCacheHeight: 256,
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
            child: Center(
              child: CircularProgressIndicator(
                color: context.dynamicPrimaryColor,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200,
            height: 200,
            color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
            child: Icon(
              Icons.tag_faces,
              color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMessage(BuildContext context, Message message) {
    final audioUrl = _getFullMediaUrl(message.audioUrl);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.play_arrow,
              color: context.dynamicPrimaryColor,
              size: 32,
            ),
            onPressed: () {
              if (audioUrl != null) {
                // TODO: Implement audio player
                // For now, show a placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Воспроизведение аудио будет реализовано позже'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Аудио сообщение',
                  style: AppTextStyles.body.copyWith(
                    color: context.dynamicPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message.fileSize != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatFileSize(message.fileSize!),
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String? _getFullMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return 'https://k-connect.ru$url';
  }

  Widget _buildReplyPreview(BuildContext context, Message message) {
    // Get replied message from state
    return BlocSelector<MessagesBloc, MessagesState, Message?>(
      selector: (state) => state.getMessage(chatId, message.replyToId),
      builder: (context, repliedMessage) {
        if (repliedMessage == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            if (message.replyToId != null && onReplyTap != null) {
              onReplyTap!(message.replyToId!);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.dynamicPrimaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repliedMessage.senderName ?? 'Пользователь',
                        style: TextStyle(
                          color: context.dynamicPrimaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        repliedMessage.content.length > 50
                            ? '${repliedMessage.content.substring(0, 50)}...'
                            : repliedMessage.content,
                        style: TextStyle(
                          color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageTextWithPostLinks(BuildContext context, String text, bool isCurrentUser) {
    // Parse post links: /api/posts/{id} or https://k-connect.ru/api/posts/{id}
    final postLinkRegex = RegExp(r'(?:https?://)?(?:k-connect\.ru)?/api/posts/(\d+)', caseSensitive: false);
    final matches = postLinkRegex.allMatches(text);
    
    if (matches.isEmpty) {
      // No post links, use regular text rendering
      return _buildMessageText(context, text, isCurrentUser);
    }

    // Split text into parts: text segments and post links
    final parts = <_MessagePart>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before link
      if (match.start > lastIndex) {
        final textBefore = text.substring(lastIndex, match.start);
        if (textBefore.isNotEmpty) {
          parts.add(_MessagePart(type: _MessagePartType.text, content: textBefore));
        }
      }

      // Add post link
      final postId = int.tryParse(match.group(1) ?? '');
      if (postId != null) {
        parts.add(_MessagePart(type: _MessagePartType.postLink, postId: postId));
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      final textAfter = text.substring(lastIndex);
      if (textAfter.isNotEmpty) {
        parts.add(_MessagePart(type: _MessagePartType.text, content: textAfter));
      }
    }

    // Build widget with text and post previews
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part.type == _MessagePartType.text) {
          return _buildMessageText(context, part.content!, isCurrentUser);
        } else {
          return _PostLinkPreview(postId: part.postId!);
        }
      }).toList(),
    );
  }

  Widget _buildMessageText(BuildContext context, String text, bool isCurrentUser) {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return Text(
        text,
        style: AppTextStyles.body.copyWith(
          color: isCurrentUser
              ? Colors.white
              : context.dynamicPrimaryColor,
        ),
      );
    }

    // Highlight search query in message text
    final query = searchQuery!.toLowerCase();
    final lowerText = text.toLowerCase();
    final matches = <_Match>[];
    
    int startIndex = 0;
    while (true) {
      final index = lowerText.indexOf(query, startIndex);
      if (index == -1) break;
      matches.add(_Match(index, index + query.length));
      startIndex = index + 1;
    }

    if (matches.isEmpty) {
      return Text(
        text,
        style: AppTextStyles.body.copyWith(
          color: isCurrentUser
              ? Colors.white
              : context.dynamicPrimaryColor,
        ),
      );
    }

    // Build TextSpan with highlighted matches
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: AppTextStyles.body.copyWith(
            color: isCurrentUser
                ? Colors.white
                : context.dynamicPrimaryColor,
          ),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: AppTextStyles.body.copyWith(
          color: isCurrentUser ? Colors.black : Colors.white,
          backgroundColor: isCurrentUser
              ? Colors.yellow
              : context.dynamicPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: AppTextStyles.body.copyWith(
          color: isCurrentUser
              ? Colors.white
              : context.dynamicPrimaryColor,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

// Helper class for search matches
class _Match {
  final int start;
  final int end;

  _Match(this.start, this.end);
}

// Helper class for message parts (text or post link)
enum _MessagePartType { text, postLink }

class _MessagePart {
  final _MessagePartType type;
  final String? content;
  final int? postId;

  _MessagePart({
    required this.type,
    this.content,
    this.postId,
  });
}

// Widget for displaying post link preview
class _PostLinkPreview extends StatefulWidget {
  final int postId;

  const _PostLinkPreview({
    required this.postId,
  });

  @override
  State<_PostLinkPreview> createState() => _PostLinkPreviewState();
}

class _PostLinkPreviewState extends State<_PostLinkPreview> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDeleted = false;
  Post? _post;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  void _loadPost() {
    // Try to get post from cache first
    final messagesBloc = context.read<MessagesBloc>();
    final cachedPost = messagesBloc.state.getCachedPost(widget.postId);

    if (cachedPost != null) {
      // Post is in cache
      setState(() {
        _post = cachedPost;
        _isLoading = false;
      });
    } else {
      // Post not in cache, load it
      setState(() {
        _isLoading = true;
      });
      messagesBloc.add(LoadPostEvent(postId: widget.postId));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to MessagesBloc state changes
    final messagesBloc = context.watch<MessagesBloc>();
    final cachedPost = messagesBloc.state.getCachedPost(widget.postId);
    final postLoadError = messagesBloc.state.postLoadErrors[widget.postId];

    if (cachedPost != null && _post == null && !_hasError && !_isDeleted) {
      // Post was loaded and cached
      setState(() {
        _post = cachedPost;
        _isLoading = false;
      });
    } else if (_post == null && !_isLoading) {
      // No post in cache and not loading - check for errors
      if (postLoadError != null && !_hasError && !_isDeleted) {
        // Check if it's a 404 error (post deleted)
        if (postLoadError.contains('404') || postLoadError.contains('Post not found')) {
          setState(() {
            _isDeleted = true;
            _isLoading = false;
          });
        } else {
          // Other error
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      } else if (cachedPost == null && !_hasError && !_isDeleted) {
        // Post might have failed to load
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Загрузка поста...'),
          ],
        ),
      );
    }

    if (_isDeleted) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Пост удален',
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError || _post == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Не удалось загрузить пост',
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return MessagePostCard(post: _post!);
  }
}
