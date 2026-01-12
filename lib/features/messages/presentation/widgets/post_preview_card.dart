/// Виджет превью поста в сообщении
///
/// Отображает компактную карточку поста с информацией об авторе,
/// текстом поста и превью медиа. Позволяет открыть полный пост.
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/authorized_cached_network_image.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../feed/domain/models/post.dart';
import '../../../../features/profile/utils/profile_navigation_utils.dart';

/// Компактная карточка превью поста для отображения в сообщении
class PostPreviewCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostPreviewCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _navigateToPost(context),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and author info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ProfileNavigationUtils.navigateToProfile(
                      context,
                      post.userName,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: ClipOval(
                        child: post.userAvatar.isNotEmpty
                            ? AuthorizedCachedNetworkImage(
                                imageUrl: post.userAvatar,
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
                              )
                            : Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => ProfileNavigationUtils.navigateToProfile(
                            context,
                            post.userName,
                          ),
                          child: Text(
                            post.userName,
                            style: AppTextStyles.postAuthor.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (post.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            post.content.length > 100
                                ? '${post.content.substring(0, 100)}...'
                                : post.content,
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Media preview if available
            if (_hasMedia(post)) _buildMediaPreview(context, post),
            // Footer with action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: context.dynamicPrimaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Открыть пост',
                    style: AppTextStyles.bodySecondary.copyWith(
                      fontSize: 11,
                      color: context.dynamicPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasMedia(Post post) {
    return (post.images != null && post.images!.isNotEmpty) ||
        post.image != null ||
        post.video != null;
  }

  Widget _buildMediaPreview(BuildContext context, Post post) {
    // Try to get first image
    String? imageUrl;
    if (post.images != null && post.images!.isNotEmpty) {
      imageUrl = post.images!.first;
    } else if (post.image != null) {
      imageUrl = post.image;
    } else if (post.videoPoster != null) {
      imageUrl = post.videoPoster;
    }

    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Container(
        height: 150,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AuthorizedCachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              memCacheWidth: 300,
              memCacheHeight: 300,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (post.video != null)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToPost(BuildContext context) {
    // TODO: Navigate to post detail screen when implemented
    // For now, navigate to profile
    ProfileNavigationUtils.navigateToProfile(context, post.userName);
  }
}
