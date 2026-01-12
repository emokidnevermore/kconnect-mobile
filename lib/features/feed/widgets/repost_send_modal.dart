/// Модальное окно для репоста и отправки поста в чаты
///
/// Предоставляет интерфейс для репоста поста или отправки его в чаты.
/// Включает горизонтальный список с кнопкой репоста и аватарами чатов,
/// поле ввода сообщения и кнопку отправки.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/authorized_cached_network_image.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../features/messages/presentation/blocs/messages_bloc.dart';
import '../../../features/messages/presentation/blocs/messages_event.dart';
import '../../../features/messages/presentation/blocs/messages_state.dart';
import '../../../features/messages/domain/models/chat.dart';
import '../../../services/posts_service.dart';
import '../../../services/storage_service.dart';
import '../domain/models/post.dart';

/// Модальное окно для репоста и отправки поста
class RepostSendModal extends StatefulWidget {
  final Post post;

  const RepostSendModal({
    super.key,
    required this.post,
  });

  /// Статический метод для открытия модального окна
  static void show(BuildContext context, Post post) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalSheetContext) {
        return RepostSendModal(post: post);
      },
    );
  }

  @override
  State<RepostSendModal> createState() => _RepostSendModalState();
}

class _RepostSendModalState extends State<RepostSendModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final PostsService _postsService = PostsService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Chat> _chats = [];
  bool _isLoadingChats = true;
  bool _isRepostSelected = true;
  int? _selectedChatId;
  bool _isSending = false;
  StreamSubscription<MessagesState>? _messagesStateSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
    _loadChats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _messagesStateSubscription?.cancel();
    super.dispose();
  }

  void _loadChats() {
    final messagesBloc = context.read<MessagesBloc>();
    final messagesState = messagesBloc.state;
    
    // Проверяем, есть ли уже загруженные чаты
    if (messagesState.chats.isNotEmpty) {
      _updateChatsList(messagesState.chats);
      return;
    }

    // Если чатов нет, загружаем их через MessagesBloc (WebSocket)
    messagesBloc.add(LoadChatsEvent());
    
    // Подписываемся на изменения состояния, чтобы получить чаты когда они загрузятся
    _messagesStateSubscription = messagesBloc.stream.listen((state) {
      if (state.chats.isNotEmpty && _isLoadingChats) {
        _updateChatsList(state.chats);
        _messagesStateSubscription?.cancel();
      }
    });

    // Таймаут: если через 5 секунд чаты не загрузились, показываем пустой список
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoadingChats && mounted) {
        setState(() {
          _isLoadingChats = false;
        });
        _messagesStateSubscription?.cancel();
      }
    });
  }

  void _updateChatsList(List<Chat> chats) {
    if (!mounted) return;
    
    final sortedChats = List<Chat>.from(chats);
    sortedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    setState(() {
      _chats = sortedChats.take(10).toList();
      _isLoadingChats = false;
    });
  }

  Future<void> _handleSend() async {
    if (_isSending) return;

    final messageText = _messageController.text.trim();

    setState(() {
      _isSending = true;
    });

    try {
      if (_isRepostSelected) {
        // Репост
        await _postsService.repostPost(widget.post.id, messageText);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (_selectedChatId != null) {
        // Отправка в чат
        final fullMessage = messageText.isNotEmpty
            ? '$messageText\n/api/posts/${widget.post.id}'
            : '/api/posts/${widget.post.id}';

        context.read<MessagesBloc>().add(
              SendMessageEvent(
                chatId: _selectedChatId!,
                content: fullMessage,
                messageType: 'text',
              ),
            );

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.4, 0.5, 0.9],
      expand: false,
      builder: (context, scrollController) {
        return ValueListenableBuilder<String?>(
          valueListenable: StorageService.appBackgroundPathNotifier,
          builder: (context, backgroundPath, child) {
            final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
            final modalColor = hasBackground
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                : Theme.of(context).colorScheme.surfaceContainer;

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: modalColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Поделиться',
                              style: AppTextStyles.h3.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Horizontal list: Repost button + Chat avatars
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    // Repost button
                                    _RepostButton(
                                      isSelected: _isRepostSelected,
                                      onTap: () {
                                        setState(() {
                                          _isRepostSelected = true;
                                          _selectedChatId = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    // Chat avatars
                                    if (_isLoadingChats)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else
                                      ..._chats.map((chat) {
                                        final isSelected = _selectedChatId == chat.id;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 12),
                                          child: _ChatAvatar(
                                            chat: chat,
                                            isSelected: isSelected,
                                            onTap: () {
                                              setState(() {
                                                _isRepostSelected = false;
                                                _selectedChatId = chat.id;
                                              });
                                            },
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Message input
                              TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: _isRepostSelected
                                      ? 'Добавить комментарий к репосту...'
                                      : 'Написать сообщение...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                style: AppTextStyles.body.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 4,
                                minLines: 2,
                              ),
                              const SizedBox(height: 16),
                              // Send button with padding to prevent overflow
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: (_isRepostSelected || _selectedChatId != null) &&
                                            !_isSending
                                        ? _handleSend
                                        : null,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isSending
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            _isRepostSelected ? 'Репостнуть' : 'Отправить',
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Круглая кнопка репоста
class _RepostButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _RepostButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RepostButton> createState() => _RepostButtonState();
}

class _RepostButtonState extends State<_RepostButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? context.dynamicPrimaryColor
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: widget.isSelected
                        ? context.dynamicPrimaryColor
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: widget.isSelected ? 3 : 1,
                  ),
                ),
                child: Icon(
                  Icons.refresh,
                  color: widget.isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 32,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Репост',
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 11,
                  color: widget.isSelected
                      ? context.dynamicPrimaryColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Круглый аватар чата
class _ChatAvatar extends StatefulWidget {
  final Chat chat;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatAvatar({
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ChatAvatar> createState() => _ChatAvatarState();
}

class _ChatAvatarState extends State<_ChatAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.chat.avatar;
    final title = widget.chat.title;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? context.dynamicPrimaryColor
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: widget.isSelected ? 3 : 1,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? AuthorizedCachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              widget.chat.isGroup ? Icons.group : Icons.person,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            widget.chat.isGroup ? Icons.group : Icons.person,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 11,
                  color: widget.isSelected
                      ? context.dynamicPrimaryColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


