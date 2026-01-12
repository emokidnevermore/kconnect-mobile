/// Компонент заголовка поста с информацией об авторе
///
/// Отображает аватар пользователя, имя, username, время публикации,
/// количество просмотров и индикатор закрепленного поста.
/// Поддерживает навигацию к профилю пользователя.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/authorized_cached_network_image.dart';
import '../../../core/constants.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../features/profile/utils/profile_navigation_utils.dart';
import '../../../core/widgets/profile_accent_color_provider.dart';
import 'post_constants.dart';
import 'post_utils.dart';

class PostHeader extends StatelessWidget {
  final Map<String, dynamic>? user;
  final int timestamp;
  final int? viewsCount;
  final bool isPinned;
  final Color? profileAccentColor;
  final VoidCallback? onMenuPressed;

  const PostHeader({
    super.key,
    required this.user,
    required this.timestamp,
    this.viewsCount,
    this.isPinned = false,
    this.profileAccentColor,
    this.onMenuPressed,
  });

  String get _userName => PostUtils.getUserName(user, 'Unknown');
  String get _userUsername => PostUtils.getUserUsername(user, '');
  String get _userAvatar => PostUtils.getUserAvatar(user);
  String get _formattedDate => timestamp != 0 ? formatRelativeTimeFromMillis(timestamp) : '';

  void _navigateToProfile(BuildContext context) {
    if (_userUsername.isNotEmpty) {
      ProfileNavigationUtils.navigateToProfile(context, _userUsername);
    }
  }

  void _showContextMenu(BuildContext context) {
    if (onMenuPressed != null) {
      onMenuPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Основная строка с аватаром и именем
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Аватар пользователя
            GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: Container(
                width: PostConstants.avatarSize,
                height: PostConstants.avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: ClipOval(
                  child: _userAvatar.isNotEmpty
                      ? AuthorizedCachedNetworkImage(
                          imageUrl: _userAvatar,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          memCacheWidth: 80,
                          memCacheHeight: 80,
                          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                          errorWidget: (context, url, error) => CachedNetworkImage(
                            imageUrl: AppConstants.userAvatarPlaceholder,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      ),
                    ),
                  ),

            const SizedBox(width: 10),

            // Информация о пользователе
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToProfile(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Имя пользователя
                    Row(
                      children: [
                        Text(_userName, style: AppTextStyles.postAuthor),
                        if (isPinned) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: context.profileAccentColor,
                          ),
                        ],
                      ],
                    ),

                    // Username
                    Text('@$_userUsername', style: AppTextStyles.postUsername),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Время и кнопка меню справа
        Positioned(
          right: -PostConstants.cardHorizontalPadding + 12,
          top: 0,
          child: Container(
            height: PostConstants.avatarSize,
            alignment: Alignment.topRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_formattedDate.isNotEmpty)
                  Text(
                    _formattedDate,
                    style: AppTextStyles.postTime,
                  ),

                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _showContextMenu(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
