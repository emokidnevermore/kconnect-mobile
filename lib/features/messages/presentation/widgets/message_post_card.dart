/// Виджет карточки поста для отображения в сообщениях
///
/// Адаптированная версия PostCardNew для использования в сообщениях.
/// Поддерживает полный формат поста из ленты с компактным дизайном
/// и без кнопки меню. Включает все типы контента (текст, медиа, музыка, опросы).
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/profile_accent_color_provider.dart';
import '../../../../core/widgets/authorized_cached_network_image.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../features/feed/domain/models/post.dart';
import '../../../../features/feed/domain/models/poll.dart';
import '../../../../features/feed/components/post_utils.dart';
import '../../../../features/feed/components/post_content.dart';
import '../../../../features/feed/components/post_music.dart';
import '../../../../features/feed/components/post_poll.dart';
import '../../../../features/feed/components/post_constants.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/media_item.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/utils/date_utils.dart';

/// Карточка поста для отображения в сообщениях
class MessagePostCard extends StatelessWidget {
  final Post post;
  final String? heroTagPrefix;

  const MessagePostCard({
    super.key,
    required this.post,
    this.heroTagPrefix,
  });

  @override
  Widget build(BuildContext context) {
    // Обработка репостов
    if (post.type == 'repost' && post.originalPost != null) {
      return _MessageRepostCardContent(
        post: post,
        heroTagPrefix: heroTagPrefix,
      );
    }

    // Обычный пост
    return _MessagePostCardContent(
      post: post,
      heroTagPrefix: heroTagPrefix,
    );
  }
}

/// Рендер контента обычного поста для сообщений
class _MessagePostCardContent extends StatefulWidget {
  final Post post;
  final String? heroTagPrefix;

  const _MessagePostCardContent({
    required this.post,
    this.heroTagPrefix,
  });

  @override
  State<_MessagePostCardContent> createState() => _MessagePostCardContentState();
}

class _MessagePostCardContentState extends State<_MessagePostCardContent> {
  void _openMediaViewer(Post post, int initialIndex) {
    final List<MediaItem> items = [];

    if (post.images != null) {
      for (final img in post.images!) {
        if (img.isNotEmpty) {
          items.add(MediaItem.image(img));
        }
      }
    } else if (post.image != null && post.image!.isNotEmpty) {
      items.add(MediaItem.image(post.image!));
    }

    if (post.video != null && post.video!.isNotEmpty) {
      String? posterUrl = (post.videoPoster != null && post.videoPoster!.isNotEmpty)
          ? post.videoPoster
          : null;
      items.add(MediaItem.video(post.video!, posterUrl: posterUrl));
    }

    final validItems = items.where((item) => item.url.isNotEmpty).toList();

    if (validItems.isNotEmpty) {
      try {
        Navigator.of(context).pushNamed(
          RouteNames.mediaViewer,
          arguments: {
            'items': validItems,
            'initialIndex': initialIndex,
            'heroTagPrefix': widget.heroTagPrefix,
            'postId': post.id,
          },
        );
      } catch (e) {
        // Игнорирование ошибок навигации
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    // Компактный дизайн для сообщений
    final hasBackground = StorageService.appBackgroundPathNotifier.value != null &&
                         StorageService.appBackgroundPathNotifier.value!.isNotEmpty;
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero, // Компактные отступы для сообщений
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Material Design 3 стиль
        ),
        child: Padding(
          padding: const EdgeInsets.all(12), // Компактные внутренние отступы
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок поста (адаптированный для сообщений)
              _MessagePostHeader(
                user: widget.post.user,
                timestamp: widget.post.createdAt,
                viewsCount: widget.post.viewsCount,
                isPinned: widget.post.isPinned,
              ),

              const SizedBox(height: 8),

              // Контент поста
              if (widget.post.content.isNotEmpty) ...[
                PostContent(content: widget.post.content),
                const SizedBox(height: 8),
              ],

              // Медиа контент
              if (PostUtils.hasMedia(widget.post.images, widget.post.image, widget.post.video)) ...[
                _MessagePostMedia(
                  images: widget.post.images,
                  singleImage: widget.post.image,
                  videoUrl: widget.post.video,
                  videoPoster: widget.post.videoPoster,
                  heroTagPrefix: widget.heroTagPrefix,
                  postId: widget.post.id,
                  onMediaTap: (index) => _openMediaViewer(widget.post, index),
                ),
                const SizedBox(height: 8),
              ],

              // Музыка
              if (PostUtils.hasMusic(widget.post.music)) ...[
                PostMusic(tracks: widget.post.music!, post: widget.post),
                const SizedBox(height: 8),
              ],

              // Опрос
              if (widget.post.poll != null) ...[
                _MessagePostPoll(
                  poll: widget.post.poll!,
                  backgroundColor: cardColor,
                ),
                const SizedBox(height: 8),
              ],


            ],
          ),
        ),
      ),
    );
  }
}

/// Репост компонент для сообщений
class _MessageRepostCardContent extends StatefulWidget {
  final Post post;
  final String? heroTagPrefix;

  const _MessageRepostCardContent({
    required this.post,
    this.heroTagPrefix,
  });

  @override
  _MessageRepostCardContentState createState() => _MessageRepostCardContentState();
}

class _MessageRepostCardContentState extends State<_MessageRepostCardContent> {
  bool _isExpanded = false;

  void _openMediaViewer(Post post, int initialIndex) {
    final List<String> urls = [];
    if (post.images != null && post.images!.isNotEmpty) {
      urls.addAll(post.images!);
    } else if (post.image != null && post.image!.isNotEmpty) {
      urls.add(post.image!);
    }
    if (post.video != null && post.videoPoster != null && post.videoPoster!.isNotEmpty) {
      urls.add(post.videoPoster!);
    }

    final List<MediaItem> items = [];
    int imageIndex = 0;
    int videoIndex = 0;

    for (final url in urls) {
      if (post.images != null && imageIndex < post.images!.length && post.images![imageIndex] == url) {
        items.add(MediaItem.image(url));
        imageIndex++;
      } else if (post.video != null && videoIndex == 0 && url == post.videoPoster) {
        items.add(MediaItem.video(post.video!, posterUrl: url));
        videoIndex++;
      } else if (post.image != null && url == post.image) {
        items.add(MediaItem.image(url));
      }
    }

    final validItems = items.where((item) => item.url.isNotEmpty).toList();

    if (validItems.isNotEmpty) {
      Navigator.of(context).pushNamed(
        RouteNames.mediaViewer,
        arguments: {
          'items': validItems,
          'initialIndex': initialIndex,
          'heroTagPrefix': widget.heroTagPrefix,
          'postId': post.id,
        },
      );
    }
  }

  void _navigateToProfile(BuildContext context, String username) {
    // TODO: Implement navigation to profile
  }

  bool _needsExpansion(String content) {
    if (content.trim().isEmpty) {
      return false;
    }

    final headerInfo = PostUtils.extractHeaderIfPresent(content);
    final hasHeader = headerInfo['hasHeader'] as bool;

    if (hasHeader) {
      return headerInfo['hasMoreContent'] as bool;
    } else {
      return content.length > PostConstants.maxContentLength;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasBackground = StorageService.appBackgroundPathNotifier.value != null &&
                         StorageService.appBackgroundPathNotifier.value!.isNotEmpty;
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final repostUser = post.user ?? {};
    final repostAvatar = PostUtils.getUserAvatar(repostUser);
    final repostName = PostUtils.getUserName(repostUser, 'Unknown');
    final repostUsername = PostUtils.getUserUsername(repostUser, '');

    final originalPost = post.originalPost!;
    final originalUser = originalPost.user ?? {};
    final originalAvatar = PostUtils.getUserAvatar(originalUser);
    final originalName = PostUtils.getUserName(originalUser, 'Unknown');
    final originalUsername = PostUtils.getUserUsername(originalUser, '');

    final needsRepostExpansion = _needsExpansion(post.content);
    final needsOriginalExpansion = _needsExpansion(originalPost.content);
    final needsCommonExpand = (post.content.isNotEmpty && needsRepostExpansion) ||
                             (originalPost.content.isNotEmpty && needsOriginalExpansion);

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header с обоими пользователями и иконкой репоста
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Репостер в верхней строке
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserAvatar(context, repostAvatar),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToProfile(context, repostUsername),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(repostName, style: AppTextStyles.postAuthor),
                                  if (post.isPinned) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.push_pin,
                                      size: 14,
                                      color: context.profileAccentColor,
                                    ),
                                  ],
                                ],
                              ),
                              Text('@$repostUsername', style: AppTextStyles.postUsername),
                            ],
                          ),
                        ),
                      ),
                      // Время без кнопки меню
                      Container(
                        alignment: Alignment.topRight,
                        child: Text(
                          formatRelativeTimeFromMillis(post.createdAt),
                          style: AppTextStyles.postTime,
                        ),
                      ),
                    ],
                  ),

                  // Оригинальный автор с отступом слева
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.refresh,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _buildSmallUserAvatar(context, originalAvatar),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _navigateToProfile(context, originalUsername),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(originalName, style: AppTextStyles.postAuthor),
                                Text('@$originalUsername', style: AppTextStyles.postUsername),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Содержание репоста (комментарий от репостера)
              if (post.content.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: context.profileAccentColor,
                        width: 2,
                      ),
                    ),
                  ),
                  child: PostContent(
                    content: post.content,
                    isExpandedOverride: needsCommonExpand ? _isExpanded : null,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Содержание оригинального поста
              if (originalPost.content.isNotEmpty) ...[
                PostContent(
                  content: originalPost.content,
                  isRepostContent: true,
                  isExpandedOverride: needsCommonExpand ? _isExpanded : null,
                ),
                const SizedBox(height: 8),
              ],

              // Медиа оригинального поста
              if (PostUtils.hasMedia(originalPost.images, originalPost.image, originalPost.video)) ...[
                _MessagePostMedia(
                  images: originalPost.images,
                  singleImage: originalPost.image,
                  videoUrl: originalPost.video,
                  videoPoster: originalPost.videoPoster,
                  heroTagPrefix: widget.heroTagPrefix,
                  postId: originalPost.id,
                  onMediaTap: (index) => _openMediaViewer(originalPost, index),
                ),
                const SizedBox(height: 8),
              ],

              // Музыка оригинального поста
              if (PostUtils.hasMusic(originalPost.music)) ...[
                PostMusic(tracks: originalPost.music!, post: originalPost),
                const SizedBox(height: 8),
              ],

              // Опрос оригинального поста
              if (originalPost.poll != null) ...[
                PostPoll(
                  poll: originalPost.poll!,
                  postId: post.id,
                  transparentBackground: false,
                  semiTransparent: false,
                  backgroundColor: cardColor,
                ),
                const SizedBox(height: 8),
              ],

              // Общая кнопка "Развернуть" если есть что развернуть
              if (needsCommonExpand && !_isExpanded) ...[
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Развернуть',
                        style: AppTextStyles.postStats.copyWith(
                          color: context.profileAccentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, String avatarUrl) {
    return GestureDetector(
      onTap: () => _navigateToProfile(context, PostUtils.getUserUsername(widget.post.user, '')),
      child: Container(
        width: 28, // Компактный размер для сообщений
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                )
              : Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 16,
                ),
        ),
      ),
    );
  }

  Widget _buildSmallUserAvatar(BuildContext context, String avatarUrl) {
    return GestureDetector(
      onTap: () => _navigateToProfile(context, PostUtils.getUserUsername(widget.post.originalPost?.user, '')),
      child: Container(
        width: 20, // Еще более компактный размер
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 12,
                  ),
                )
              : Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 12,
                ),
        ),
      ),
    );
  }
}

/// Адаптированный компонент медиа для сообщений с ограниченной высотой и авторизацией
class _MessagePostMedia extends StatelessWidget {
  final List<String>? images;
  final String? singleImage;
  final String? videoUrl;
  final String? videoPoster;
  final String? heroTagPrefix;
  final int? postId;
  final ValueChanged<int>? onMediaTap;

  const _MessagePostMedia({
    this.images,
    this.singleImage,
    this.videoUrl,
    this.videoPoster,
    this.heroTagPrefix,
    this.postId,
    this.onMediaTap,
  });

  List<String> get _allMediaUrls {
    final List<String> urls = [];

    if (images != null && images!.isNotEmpty) {
      urls.addAll(images!);
    } else if (singleImage != null && singleImage!.isNotEmpty) {
      urls.add(singleImage!);
    }

    if (videoUrl != null && videoUrl!.isNotEmpty) {
      if (videoPoster != null && videoPoster!.isNotEmpty) {
        urls.add(videoPoster!);
      } else {
        urls.add('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4gIDxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjMDAwMDAwIi8+ICA8Y2lyY2xlIGN4PSIyMDAiIGN5PSIxNTAiIHI9IjUwIiBmaWxsPSIjZmZmZmZmIi8+ICA8dGV4dCB4PSIyMDAiIHk9IjI2MCIgZmlsbD0iI2ZmZmZmZiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxOCI+VmlkZW88L3RleHQ+IDwvc3ZnPg==');
      }
    }

    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final urls = _allMediaUrls;

    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = PostConstants.cardHorizontalPadding * 2;
    final availableWidth = screenWidth - cardPadding;
    final containerWidth = availableWidth;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 200, // Ограничение максимальной высоты для сообщений
      ),
      child: _buildImagesGrid(context, urls, containerWidth, 4.0),
    );
  }

  Widget _buildImagesGrid(BuildContext context, List<String> imageUrls, double containerWidth, double spacing) {
    final int imageCount = imageUrls.length;

    if (imageCount == 1) {
      // 1 изображение/видео с Hero анимацией
      final prefix = heroTagPrefix ?? 'message_media';
      // Используем postId для уникальности
      final postIdSuffix = postId != null ? '_$postId' : '';
      final heroTag = '${prefix}_${imageUrls[0].hashCode}_0$postIdSuffix';
      final isVideo = videoUrl != null && videoUrl!.isNotEmpty && videoPoster != null && imageUrls[0] == videoPoster;

      return GestureDetector(
        onTap: onMediaTap != null ? () => onMediaTap!(0) : null,
        child: Hero(
          tag: heroTag,
          transitionOnUserGestures: true,
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: containerWidth,
              width: containerWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PostConstants.borderRadius),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PostConstants.borderRadius),
                    child: AuthorizedCachedNetworkImage(
                      imageUrl: imageUrls[0],
                      width: containerWidth,
                      height: containerWidth,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      memCacheWidth: 500,
                      memCacheHeight: 500,
                      placeholder: (context, url) => Container(
                        width: containerWidth,
                        height: containerWidth,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: containerWidth,
                        height: containerWidth,
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
                  // Кнопка play
                  if (isVideo)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.scrim,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Расчет размеров для сетки
    int maxPerRow = imageCount <= 4 ? 2 : 3;
    double imageSize = (containerWidth - (maxPerRow - 1) * spacing) / maxPerRow;

    List<List<String>> rows = [];
    for (int i = 0; i < imageCount; i += maxPerRow) {
      int end = (i + maxPerRow > imageCount) ? imageCount : i + maxPerRow;
      rows.add(imageUrls.sublist(i, end));
    }

    return Column(
      children: rows.asMap().entries.map((rowEntry) {
        final rowIndex = rowEntry.key;
        final rowImages = rowEntry.value;

        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < rows.length - 1 ? spacing : 0),
          child: Row(
            children: rowImages.asMap().entries.map((imageEntry) {
              final imageIndex = imageEntry.key;
              final imageUrl = imageEntry.value;
              final globalIndex = rows.take(rowIndex).fold(0, (sum, row) => sum + row.length) + imageIndex;

              final prefix = heroTagPrefix ?? 'message_media';
              // Используем postId для уникальности
              final postIdSuffix = postId != null ? '_$postId' : '';
              final heroTag = '${prefix}_${imageUrl.hashCode}_$globalIndex$postIdSuffix';

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: imageIndex < rowImages.length - 1 ? spacing : 0),
                  child: GestureDetector(
                    onTap: onMediaTap != null ? () {
                      onMediaTap!(globalIndex);
                    } : null,
                    child: Hero(
                      tag: heroTag,
                      transitionOnUserGestures: true,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          height: imageSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(PostConstants.borderRadius),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(PostConstants.borderRadius),
                            child: AuthorizedCachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              placeholder: (context, url) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
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
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Адаптированный компонент опроса для сообщений
class _MessagePostPoll extends StatelessWidget {
  final Poll poll;
  final Color? backgroundColor;

  const _MessagePostPoll({
    required this.poll,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = context.profileAccentColor;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      color: backgroundColor ?? colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Индикатор типа опроса
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'ПУБЛИЧНЫЙ ОПРОС',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Вопрос опроса
            Text(
              poll.question,
              style: AppTextStyles.h3.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Информация о количестве вариантов
            Row(
              children: [
                Icon(
                  Icons.list_alt,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${poll.options.length} ${_getOptionsText(poll.options.length)}',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                // Троеточие для указания возможности взаимодействия
                Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: accentColor,
                ),
              ],
            ),
            // Информация о количестве голосов и времени истечения
            if (poll.totalVotes > 0 || (poll.expiresAt != null && !poll.isExpired)) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Количество голосов слева
                  if (poll.totalVotes > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.how_to_vote,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${poll.totalVotes} ${_getVotesText(poll.totalVotes)}',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  // Время истечения справа
                  if (poll.expiresAt != null && !poll.isExpired)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiresAt(poll.expiresAt),
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatExpiresAt(String? expiresAt) {
    if (expiresAt == null) return '';
    try {
      final dateTime = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = dateTime.difference(now);

      if (difference.isNegative) return 'Истек';

      if (difference.inDays > 0) {
        return 'Осталось ${difference.inDays} дн.';
      } else if (difference.inHours > 0) {
        return 'Осталось ${difference.inHours} ч.';
      } else if (difference.inMinutes > 0) {
        return 'Осталось ${difference.inMinutes} мин.';
      } else {
        return 'Скоро истечет';
      }
    } catch (e) {
      return '';
    }
  }

  String _getOptionsText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'вариант';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'варианта';
    } else {
      return 'вариантов';
    }
  }

  String _getVotesText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'голос';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'голоса';
    } else {
      return 'голосов';
    }
  }
}

/// Адаптированный заголовок поста для сообщений (без меню)
class _MessagePostHeader extends StatelessWidget {
  final Map<String, dynamic>? user;
  final int? timestamp;
  final int? viewsCount;
  final bool isPinned;

  const _MessagePostHeader({
    required this.user,
    this.timestamp,
    this.viewsCount,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final userAvatar = PostUtils.getUserAvatar(user);
    final userName = PostUtils.getUserName(user, 'Unknown');
    final userUsername = PostUtils.getUserUsername(user, '');

    return Row(
      children: [
        // Аватар пользователя
        GestureDetector(
          onTap: () {
            // TODO: Navigate to profile
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: ClipOval(
              child: userAvatar.isNotEmpty
                  ? Image.network(
                      userAvatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Информация о пользователе
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: Navigate to profile
                    },
                    child: Text(
                      userName,
                      style: AppTextStyles.postAuthor.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.push_pin,
                      size: 12,
                      color: context.profileAccentColor,
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to profile
                },
                child: Text(
                  '@$userUsername',
                  style: AppTextStyles.postUsername.copyWith(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Время и просмотры (справа)
        if (timestamp != null)
          Text(
            formatRelativeTimeFromMillis(timestamp!),
            style: AppTextStyles.postTime.copyWith(
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}
