/// Виджет поля ввода сообщения
///
/// Отображает текстовое поле и кнопку отправки сообщения
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/services/messenger_websocket_service.dart';
import 'package:kconnect_mobile/injection.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/messages/domain/models/message.dart';
import 'package:kconnect_mobile/shared/widgets/media_picker_modal.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/sticker_picker.dart';

/// Поле ввода сообщения
class ChatMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final int chatId;
  final Message? replyToMessage;
  final VoidCallback? onCancelReply;
  final Message? editingMessage;
  final VoidCallback? onCancelEdit;

  const ChatMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.chatId,
    this.replyToMessage,
    this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
  });

  @override
  State<ChatMessageInput> createState() => _ChatMessageInputState();
}

class _ChatMessageInputState extends State<ChatMessageInput> {
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showStickers = false;

  @override
  void dispose() {
    _stopTyping();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      final wsService = locator<MessengerWebSocketService>();
      if (wsService.isAuthenticated) {
        wsService.sendTypingStart(widget.chatId);
        debugPrint('ChatMessageInput: Started typing');
      }
    }
    
    // Reset timer - will send typing_end after 3 seconds of inactivity
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      final wsService = locator<MessengerWebSocketService>();
      if (wsService.isAuthenticated) {
        wsService.sendTypingEnd(widget.chatId);
        debugPrint('ChatMessageInput: Stopped typing');
      }
    }
    _typingTimer?.cancel();
  }

  void _showMediaPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MediaPickerModal(
        photoOnly: true,
        singleSelection: true,
        onMediaSelected: (imagePaths, videoPath, videoThumbnailPath, tracks) {
          final messagesBloc = context.read<MessagesBloc>();
          
          // Handle image
          if (imagePaths.isNotEmpty) {
            messagesBloc.add(SendMediaMessageEvent(
              chatId: widget.chatId,
              filePath: imagePaths.first,
              messageType: 'photo',
              replyToId: widget.replyToMessage?.id,
            ));
          }
          
          // Handle video
          if (videoPath != null) {
            messagesBloc.add(SendMediaMessageEvent(
              chatId: widget.chatId,
              filePath: videoPath,
              messageType: 'video',
              replyToId: widget.replyToMessage?.id,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview or Edit indicator
            if (widget.replyToMessage != null || widget.editingMessage != null)
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
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
                            widget.editingMessage != null
                                ? 'Редактирование сообщения'
                                : widget.replyToMessage!.senderName ?? 'Пользователь',
                            style: TextStyle(
                              color: context.dynamicPrimaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.replyToMessage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.replyToMessage!.content.length > 50
                                  ? '${widget.replyToMessage!.content.substring(0, 50)}...'
                                  : widget.replyToMessage!.content,
                              style: TextStyle(
                                color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.editingMessage != null
                          ? widget.onCancelEdit
                          : widget.onCancelReply,
                      icon: Icon(
                        Icons.close,
                        color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            // Input field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.transparent,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Media picker button
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showMediaPicker(context),
                          icon: Icon(
                            Icons.attach_file,
                            color: context.dynamicPrimaryColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Left card: text input
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: TextField(
                            controller: widget.controller,
                        decoration: InputDecoration(
                          hintText: widget.editingMessage != null
                              ? 'Редактировать сообщение...'
                              : 'Введите сообщение...',
                          hintStyle: TextStyle(
                            color: context.dynamicPrimaryColor.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          isDense: false,
                        ),
                            style: TextStyle(
                              color: context.dynamicPrimaryColor,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) => _startTyping(),
                            onSubmitted: (_) {
                              _stopTyping();
                              widget.onSend();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right card: send button
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _stopTyping();
                            widget.onSend();
                          },
                          icon: Icon(
                            Icons.arrow_upward,
                            color: context.dynamicPrimaryColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Sticker picker
            if (_showStickers)
              StickerPicker(
                onStickerSelected: (stickerId, stickerUrl) {
                  // Send sticker message
                  final messagesBloc = context.read<MessagesBloc>();
                  messagesBloc.add(SendMessageEvent(
                    chatId: widget.chatId,
                    content: stickerId, // Format: [STICKER_packId_stickerId]
                    messageType: 'sticker',
                    replyToId: widget.replyToMessage?.id,
                  ));
                  
                  // Close sticker picker
                  setState(() {
                    _showStickers = false;
                  });
                },
              ),
          ],
        );
      },
    );
  }
}

