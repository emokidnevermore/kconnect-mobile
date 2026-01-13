/// Модальное окно комментариев к посту
///
/// Предоставляет интерфейс для просмотра, добавления и управления комментариями.
/// Включает поддержку вложенных комментариев, лайков и Markdown форматирования.
/// Управляет состоянием комментариев через FeedBloc.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/authorized_cached_network_image.dart';
import '../../../core/widgets/profile_accent_color_provider.dart';
import '../../../core/constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../features/auth/presentation/blocs/auth_bloc.dart';
import '../../../features/auth/presentation/blocs/auth_state.dart';
import '../../../features/feed/presentation/blocs/feed_bloc.dart';
import '../../../features/feed/presentation/blocs/feed_state.dart';
import '../../../features/feed/presentation/blocs/feed_event.dart';
import '../domain/models/comment.dart';
import '../domain/models/post.dart';
import '../../../features/profile/utils/profile_navigation_utils.dart';
import '../../../services/storage_service.dart';

/// Кастомная физика прокрутки для комментариев
///
/// Отключает отскок при прокрутке вверх за пределы списка,
/// сохраняя стандартное поведение для нижней границы.
class CustomScrollPhysics extends BouncingScrollPhysics {
  const CustomScrollPhysics({super.parent});

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Если отскок вверх (попытка прокрутки вверх за пределы минимума), не отскакивать
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return 0.0;
    }
    // В противном случае использовать стандартное отскакивание для нижней границы
    return super.applyBoundaryConditions(position, value);
  }
}

/// Основной контейнер для комментариев поста
///
/// Содержит список комментариев и поле ввода нового комментария.
/// Используется в Material 3 BottomSheet.
class CommentsBody extends StatelessWidget {
  /// ID поста, комментарии которого отображаются
  final int postId;

  /// Объект поста (может использоваться для дополнительной информации)
  final Post post;

  /// ScrollController для прокрутки списка комментариев
  final ScrollController? scrollController;

  const CommentsBody({
    super.key,
    required this.postId,
    required this.post,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          final comments = state.comments;

          return Column(
            children: [
              Expanded(
                child: CommentsList(
                  postId: postId,
                  comments: comments,
                  commentsStatus: state.commentsStatus,
                  scrollController: scrollController,
                ),
              ),
              CommentsInput(
                postId: postId,
                scrollController: scrollController,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Виджет списка комментариев
///
/// Отображает прокручиваемый список комментариев с поддержкой
/// вложенных ответов, лайков и обработки ошибок загрузки.
class CommentsList extends StatefulWidget {
  /// ID поста, комментарии которого отображаются
  final int postId;

  /// Список комментариев для отображения
  final List<Comment> comments;

  /// Статус загрузки комментариев
  final CommentsStatus commentsStatus;

  /// ScrollController для прокрутки списка
  final ScrollController? scrollController;

  const CommentsList({
    super.key,
    required this.postId,
    required this.comments,
    required this.commentsStatus,
    this.scrollController,
  });

  @override
  State<CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends State<CommentsList> {
  late final ScrollController _scrollController;
  final Map<String, String> _preprocessedCache = {};

  String _preprocessText(String text) {
    if (_preprocessedCache.containsKey(text)) {
      return _preprocessedCache[text]!;
    }
    final result = text.replaceAllMapped(RegExp(r'#([\wа-яё]+)', caseSensitive: false), (match) {
      return '[#${match[1]}](hashtag)';
    });
    _preprocessedCache[text] = result;
    return result;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    context.read<FeedBloc>().add(LoadCommentsEvent(widget.postId));
  }

  @override
  void dispose() {
    // Dispose only if we created the controller ourselves
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  List<Comment> _getCommentTree(List<Comment> comments) {
    return comments;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;

    if (widget.commentsStatus == CommentsStatus.loading && widget.comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.commentsStatus == CommentsStatus.failure) {
      return _buildCommentsErrorWidget();
    }

    if (widget.comments.isEmpty) {
      return Center(
        child: Text('Нет комментариев', style: AppTextStyles.postStats),
      );
    }

    final commentTree = _getCommentTree(widget.comments);

    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, feedState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListView.separated(
            controller: _scrollController,
            physics: const CustomScrollPhysics(),
            itemCount: commentTree.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final comment = commentTree[index];
              final isProcessing = feedState.processingCommentLikes.contains(comment.id);
              return _AnimatedCommentThread(
                index: index,
                comment: comment,
                currentUserId: currentUserId,
                preprocessText: _preprocessText,
                isProcessing: isProcessing,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCommentsErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Не удалось загрузить комментарии',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (context.read<FeedBloc>().state.commentsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.read<FeedBloc>().state.commentsError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              context.read<FeedBloc>().add(LoadCommentsEvent(widget.postId));
            },
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }
}

/// Animated wrapper для CommentThread с staggered animation
class _AnimatedCommentThread extends StatefulWidget {
  final int index;
  final Comment comment;
  final int? currentUserId;
  final String Function(String) preprocessText;
  final bool isProcessing;

  const _AnimatedCommentThread({
    required this.index,
    required this.comment,
    required this.currentUserId,
    required this.preprocessText,
    this.isProcessing = false,
  });

  @override
  State<_AnimatedCommentThread> createState() => _AnimatedCommentThreadState();
}

class _AnimatedCommentThreadState extends State<_AnimatedCommentThread>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Ограничиваем количество анимируемых комментариев
    // Анимируем только первые 30 комментариев, остальные показываем сразу
    if (widget.index > 30) {
      _controller.value = 1.0; // Сразу показываем комментарий
      _fadeAnimation = AlwaysStoppedAnimation(1.0);
      _slideAnimation = AlwaysStoppedAnimation(Offset.zero);
    } else {
      final delay = widget.index * 50; // Stagger delay
      final animationDuration = _controller.duration!.inMilliseconds;
      // Ограничиваем begin значением 0.0, чтобы избежать ошибки Interval
      // Используем минимум между delay/400 и 0.8, чтобы оставить место для анимации
      final intervalStart = (delay / animationDuration).clamp(0.0, 0.8);
      final intervalEnd = 1.0;
      
      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            intervalStart,
            intervalEnd,
            curve: Curves.easeOut,
          ),
        ),
      );
      
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            intervalStart,
            intervalEnd,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
      
      // Start animation with delay, но не больше длительности анимации
      final actualDelay = delay.clamp(0, animationDuration);
      if (actualDelay > 0) {
        Future.delayed(Duration(milliseconds: actualDelay), () {
          if (mounted && _controller.status != AnimationStatus.completed) {
            _controller.forward();
          }
        });
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CommentThread(
          comment: widget.comment,
          currentUserId: widget.currentUserId,
          preprocessText: widget.preprocessText,
          isProcessing: widget.isProcessing,
        ),
      ),
    );
  }
}

class CommentThread extends StatefulWidget {
  final Comment comment;
  final int? currentUserId;
  final String Function(String) preprocessText;
  final bool isProcessing;

  const CommentThread({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.preprocessText,
    this.isProcessing = false,
  });

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  bool _showAllReplies = false;

  @override
  Widget build(BuildContext context) {
    final replies = widget.comment.replies;
    final visibleReplies = _showAllReplies ? replies : replies.take(2).toList();
    final hiddenRepliesCount = replies.length - visibleReplies.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentItem(
          comment: widget.comment,
          currentUserId: widget.currentUserId,
          preprocessText: widget.preprocessText,
          isProcessing: widget.isProcessing,
        ),
        if (replies.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 28), // Полоска на 8px от левого края
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.profileAccentColor,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 8), // Ответы на 16px от левого края (8+8)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...visibleReplies.map((reply) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: CommentThread(
                        comment: reply,
                        currentUserId: widget.currentUserId,
                        preprocessText: widget.preprocessText,
                        isProcessing: false,
                      ),
                    );
                  }),
                  if (hiddenRepliesCount > 0 && !_showAllReplies)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => _showAllReplies = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Показать еще $hiddenRepliesCount ${hiddenRepliesCount == 1 ? 'ответ' : hiddenRepliesCount < 5 ? 'ответа' : 'ответов'}',
                            style: AppTextStyles.postStats.copyWith(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
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
    );
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;
  final int? currentUserId;
  final String Function(String) preprocessText;
  final bool isProcessing;

  const CommentItem({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.preprocessText,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = comment.userAvatar;
    final name = comment.userName;
    final text = comment.content;
    final createdAt = comment.createdAt;
    final likesCount = comment.likesCount;
    final isLiked = comment.userLiked;

    // Используем логику цвета как у постов
    final hasBackground = StorageService.appBackgroundPathNotifier.value != null &&
        StorageService.appBackgroundPathNotifier.value!.isNotEmpty;
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  ProfileNavigationUtils.navigateToProfile(context, comment.username);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: ClipOval(
                    child: AuthorizedCachedNetworkImage(
                      imageUrl: avatar.isNotEmpty ? avatar : AppConstants.userAvatarPlaceholder,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      memCacheWidth: 64,
                      memCacheHeight: 64,
                      placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) => CachedNetworkImage(
                        imageUrl: AppConstants.userAvatarPlaceholder,
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            ProfileNavigationUtils.navigateToProfile(context, comment.username);
                          },
                          child: Text(
                            name,
                            style: AppTextStyles.postAuthor.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          date_utils.formatRelativeTimeFromMillis(createdAt),
                          style: AppTextStyles.postTime.copyWith(fontSize: 11), // Уменьшен размер
                        ),
                        const Spacer(),
                        if (comment.userId == currentUserId)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => context.read<FeedBloc>().add(DeleteCommentEvent(comment.id)),
                            icon: Icon(
                              Icons.delete,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: preprocessText(text),
            styleSheet: MarkdownStyleSheet(
              p: AppTextStyles.postContent.copyWith(
                height: 1.3,
                fontSize: 14,
              ),
            ),
          ),
          if (comment.image != null && comment.image!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: AuthorizedCachedNetworkImage(
                    imageUrl: comment.image!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.warning,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<FeedBloc>().add(StartReplyModeEvent(comment));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ответить',
                        style: AppTextStyles.postStats.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: isProcessing ? null : () => context.read<FeedBloc>().add(LikeCommentEvent(comment.id)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isProcessing
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              Icons.favorite,
                              size: 16,
                              color: isLiked ? context.dynamicPrimaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      const SizedBox(width: 4),
                      Text(
                        '$likesCount',
                        style: AppTextStyles.postStats.copyWith(
                          fontSize: 11,
                          color: isLiked ? context.dynamicPrimaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentsInput extends StatefulWidget {
  final int postId;
  final ScrollController? scrollController;

  const CommentsInput({
    super.key,
    required this.postId,
    this.scrollController,
  });

  @override
  State<CommentsInput> createState() => _CommentsInputState();
}

class _CommentsInputState extends State<CommentsInput> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendMessage(Comment? replyingTo, List<Comment> comments) {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      final feedBloc = context.read<FeedBloc>();

      if (replyingTo != null) {
        feedBloc.add(SendReplyEvent(text));
      } else {
        feedBloc.add(AddCommentEvent(widget.postId, text));
      }

      _commentController.clear();

      // Smooth scroll to top (newest comment is first)
      if (widget.scrollController != null && widget.scrollController!.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.scrollController != null && widget.scrollController!.hasClients) {
            widget.scrollController!.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        final replyingTo = state.replyingTo;
        final comments = state.comments;
        debugPrint('CommentsInput build - replyingTo: ${replyingTo?.id}, replyMode: ${state.replyMode}');

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyingTo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ответ на ${replyingTo.userName}:',
                                style: AppTextStyles.postAuthor.copyWith(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyingTo.content,
                                style: AppTextStyles.postContent.copyWith(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () {
                              debugPrint('Close button pressed - dispatching CancelReplyModeEvent');
                              context.read<FeedBloc>().add(const CancelReplyModeEvent());
                            },
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: replyingTo != null ? 'Написать ответ...' : 'Написать комментарий...',
                          border: InputBorder.none,
                        ),
                        style: AppTextStyles.postContent.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: context.dynamicPrimaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _sendMessage(replyingTo, comments),
                        icon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
