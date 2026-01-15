/// Компонент аватара и статистики профиля пользователя
///
/// Отображает аватар пользователя, статистику (подписки/подписчики/посты)
/// и кнопку действия (редактировать/подписаться/отписаться).
/// Поддерживает различные состояния взаимоотношений между пользователями.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../core/widgets/authorized_cached_network_image.dart';
import '../../../core/media_item.dart';
import '../../../routes/route_names.dart';
import '../domain/models/user_profile.dart';
import '../domain/models/following_info.dart';
import 'profile_achievement_badge.dart';

/// Виджет аватара и статистики профиля
///
/// Комплексный компонент для отображения основной информации о профиле:
/// аватар, статистика подписок, кнопка действия в зависимости от отношений.
class ProfileAvatarStats extends StatefulWidget {
  final UserProfile profile;
  final FollowingInfo? followingInfo;
  final bool isOwnProfile;
  final bool isSkeleton;
  final Color accentColor;
  final VoidCallback? onEditPressed;
  final Function()? onFollowPressed;
  final Function()? onUnfollowPressed;
  final bool hideActionButton;
  final ColorScheme? profileColorScheme;
  final bool hasProfileBackground;

  const ProfileAvatarStats({
    super.key,
    required this.profile,
    this.followingInfo,
    this.isOwnProfile = false,
    this.isSkeleton = false,
    required this.accentColor,
    this.onEditPressed,
    this.onFollowPressed,
    this.onUnfollowPressed,
    this.hideActionButton = false,
    this.profileColorScheme,
    this.hasProfileBackground = false,
  });

  @override
  State<ProfileAvatarStats> createState() => _ProfileAvatarStatsState();
}

class _ProfileAvatarStatsState extends State<ProfileAvatarStats> {
  bool get _isAccentWhite => widget.accentColor.computeLuminance() > 0.85;

  String get _buttonText {
    if (widget.followingInfo == null) {
      return 'Загрузка...';
    }

    final isFriend = widget.followingInfo!.currentUserIsFriend;
    final isFollowing = widget.followingInfo!.currentUserFollows;
    final followsBack = widget.followingInfo!.followsBack;

    if (followsBack && isFollowing) {
      return 'Вы друзья';
    } else if (isFriend) {
      return 'Вы друзья';
    } else if (followsBack && !isFollowing) {
      return 'Подписан на вас';
    } else if (isFollowing) {
      return 'Вы подписаны';
    } else {
      return 'Подписаться';
    }
  }

  Color get _buttonColor {
    if (widget.followingInfo == null) {
      return Colors.grey;
    }

    final isFollowing = widget.followingInfo!.currentUserFollows;
    final followsBack = widget.followingInfo!.followsBack;

    if ((followsBack && isFollowing) || widget.followingInfo!.currentUserIsFriend) {
      return Colors.green;
    } else if (followsBack && !isFollowing) {
      return Colors.grey;
    } else if (isFollowing) {
      return Colors.grey;
    } else {
      return widget.accentColor;
    }
  }

  VoidCallback? get _buttonAction {
    if (widget.followingInfo == null) {
      return null;
    }

    final isFollowing = widget.followingInfo!.currentUserFollows;
    final followsBack = widget.followingInfo!.followsBack;

    if ((followsBack && isFollowing) || widget.followingInfo!.currentUserIsFriend) {
      return null; // No action for friends
    } else if (isFollowing) {
      return widget.onUnfollowPressed;
    } else {
      return widget.onFollowPressed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar and Name/Username Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _buildAvatar(),

            const SizedBox(width: 16),

            // Name and Username
            Expanded(
              child: _buildNameAndUsername(context),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Statistics - по центру
        Row(
          children: [
            Expanded(
              child: _StatItem(
                key: ValueKey('stat_following_${widget.profile.id}'),
                label: 'Подписки',
                value: widget.profile.followingCount.toString(),
                accentColor: widget.accentColor,
                profileColorScheme: widget.profileColorScheme,
                hasProfileBackground: widget.hasProfileBackground,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatItem(
                key: ValueKey('stat_followers_${widget.profile.id}'),
                label: 'Подписчики',
                value: widget.profile.followersCount.toString(),
                accentColor: widget.accentColor,
                profileColorScheme: widget.profileColorScheme,
                hasProfileBackground: widget.hasProfileBackground,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatItem(
                key: ValueKey('stat_posts_${widget.profile.id}'),
                label: 'Посты',
                value: widget.profile.postsCount.toString(),
                accentColor: widget.accentColor,
                profileColorScheme: widget.profileColorScheme,
                hasProfileBackground: widget.hasProfileBackground,
              ),
            ),
          ],
        ),
        
        // Action button (Edit/Follow) - скрыта для чужого профиля
        if (!widget.hideActionButton) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _buttonColor,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: widget.isOwnProfile ? widget.onEditPressed : _buttonAction,
              child: Text(
                widget.isOwnProfile ? 'Редактировать' : _buttonText,
                style: TextStyle(
                  color: _buttonColor == widget.accentColor && _isAccentWhite
                      ? Colors.black
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNameAndUsername(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                widget.profile.name,
                style: AppTextStyles.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.0, // Убираем встроенные отступы текста
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Achievement badge справа от имени
            if (widget.profile.achievement != null && widget.profile.achievement!.imagePath.isNotEmpty) ...[
              const SizedBox(width: 8),
              ProfileAchievementBadge(achievement: widget.profile.achievement!),
            ],
            if (widget.profile.verification?.status == 'verified') ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.verified,
                color: Colors.blue,
                size: 20,
              ),
            ],
          ],
        ),
        Text(
          '@${widget.profile.username}',
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.0, // Убираем встроенные отступы текста
          ),
        ),
        // Status (если есть)
        if (widget.profile.statusText?.isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          _buildStatusDisplay(),
        ],
      ],
    );
  }

  void _onAvatarTap() {
    if (widget.profile.avatarUrl != null &&
        widget.profile.avatarUrl!.isNotEmpty &&
        widget.profile.avatarUrl != AppConstants.userAvatarPlaceholder) {
      final mediaItem = MediaItem.image(widget.profile.avatarUrl!);
      Navigator.of(context).pushNamed(
        RouteNames.mediaViewer,
        arguments: {
          'items': [mediaItem],
          'initialIndex': 0,
        },
      );
    }
  }

  Widget _buildStatusDisplay() {
    if (widget.profile.statusText == null || widget.profile.statusText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final displayData = _parseStatusText(widget.profile.statusText!);

    return Align(
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: displayData.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
      child: displayData.icon != null
          ? IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    displayData.icon!,
                    color: displayData.textColor,
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      displayData.text,
                      style: AppTextStyles.body.copyWith(
                        color: displayData.textColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
              : Text(
                  displayData.text,
                  style: AppTextStyles.body.copyWith(
                    color: displayData.textColor,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }

  StatusDisplayData _parseStatusText(String statusText) {
    final backgroundColor = _parseColor(widget.profile.statusColor);
    final isBgLight = backgroundColor.computeLuminance() > 0.85;
    final textColor = isBgLight ? Colors.black : AppColors.textPrimary;

    // Parse icon and text: {icon}text
    if (statusText.startsWith('{')) {
      final closeBraceIndex = statusText.indexOf('}');
      if (closeBraceIndex > 1) {
        final iconName = statusText.substring(1, closeBraceIndex);
        final icon = _getStatusIcon(iconName);
        final text = statusText.substring(closeBraceIndex + 1).trim();

        return StatusDisplayData(
          text: text,
          icon: icon,
          backgroundColor: backgroundColor,
          textColor: textColor,
        );
      }
    }

    return StatusDisplayData(
      text: statusText,
      icon: null,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  Color _parseColor(String? statusColor) {
    if (statusColor == null || statusColor.isEmpty) {
      return const Color(0xFFFFFFFF); // Белый по умолчанию
    }

    try {
      // Убираем # если есть
      final colorStr = statusColor.startsWith('#')
          ? statusColor.substring(1)
          : statusColor;

      // Парсим hex цвет
      final colorInt = int.parse(colorStr, radix: 16);

      // Добавляем alpha если не указан
      if (colorStr.length == 6) {
        return Color(colorInt | 0xFF000000);
      } else if (colorStr.length == 8) {
        return Color(colorInt);
      } else {
        return const Color(0xFFFFFFFF);
      }
    } catch (e) {
      return const Color(0xFFFFFFFF);
    }
  }

  String? _getStatusIcon(String iconName) {
    switch (iconName) {
      case 'info':
        return 'lib/assets/icons/status_icons/info.svg';
      case 'cloud':
        return 'lib/assets/icons/status_icons/cloud.svg';
      case 'minion':
        return 'lib/assets/icons/status_icons/minion.svg';
      case 'heart':
        return 'lib/assets/icons/status_icons/heart.svg';
      case 'star':
        return 'lib/assets/icons/status_icons/star.svg';
      case 'music':
        return 'lib/assets/icons/status_icons/music.svg';
      case 'location':
        return 'lib/assets/icons/status_icons/location.svg';
      case 'cake':
        return 'lib/assets/icons/status_icons/cake.svg';
      case 'chat':
        return 'lib/assets/icons/status_icons/chat.svg';
      default:
        return null;
    }
  }

  Widget _buildAvatar() {
    final String avatarUrl = (widget.profile.avatarUrl != null && widget.profile.avatarUrl!.isNotEmpty)
        ? widget.profile.avatarUrl!
        : AppConstants.userAvatarPlaceholder;

    // Hero tag для аватара профиля - должен совпадать с тегом в MediaViewer
    // Используем формат profile_avatar_urlhashcode_0 (index всегда 0 для аватара)
    final heroTag = 'profile_avatar_${avatarUrl.hashCode}_0';

    return GestureDetector(
      onTap: _onAvatarTap,
      child: Hero(
        tag: heroTag,
        transitionOnUserGestures: true,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
            ),
            child: ClipOval(
              child: AuthorizedCachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                errorWidget: (context, url, error) => CachedNetworkImage(
                  imageUrl: AppConstants.userAvatarPlaceholder,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                  errorWidget: (context, url, error) => Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.grey,
                      ),
                      if (widget.isSkeleton)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha:0.3),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final ColorScheme? profileColorScheme;
  final bool hasProfileBackground;

  const _StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.profileColorScheme,
    this.hasProfileBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = hasProfileBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : (profileColorScheme?.surfaceContainerLow ?? Theme.of(context).colorScheme.surfaceContainerLow);

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTextStyles.h2.copyWith(
                color: accentColor,
                fontSize: 22,
              ),
        ),
        const SizedBox.shrink(),
        Text(
              label,
              style: AppTextStyles.postStats.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class StatusDisplayData {
  final String text;
  final String? icon;
  final Color backgroundColor;
  final Color textColor;

  const StatusDisplayData({
    required this.text,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
  });
}
