/// Компонент аватара и статистики профиля пользователя
///
/// Отображает аватар пользователя, статистику (подписки/подписчики/посты)
/// и кнопку действия (редактировать/подписаться/отписаться).
/// Поддерживает различные состояния взаимоотношений между пользователями.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/widgets/authorized_cached_network_image.dart';
import '../../../core/media_item.dart';
import '../../../routes/route_names.dart';
import '../domain/models/user_profile.dart';
import '../domain/models/following_info.dart';
import 'profile_achievement_badge.dart';
import 'profile_subscription_badge.dart';

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
                label: 'Подписки',
                value: widget.profile.followingCount.toString(),
                accentColor: widget.accentColor,
                profileColorScheme: widget.profileColorScheme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatItem(
                label: 'Подписчики',
                value: widget.profile.followersCount.toString(),
                accentColor: widget.accentColor,
                profileColorScheme: widget.profileColorScheme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatItem(
                label: 'Посты',
                value: widget.profile.postsCount.toString(),
                accentColor: widget.accentColor,
                profileColorScheme: widget.profileColorScheme,
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
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '@${widget.profile.username}',
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            // Subscription badge под username
            if (widget.profile.subscription != null && widget.profile.subscription!.active) ...[
              const SizedBox(width: 8),
              ProfileSubscriptionBadge(
                subscription: widget.profile.subscription!,
                accentColor: widget.accentColor,
              ),
            ],
          ],
        ),
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

  const _StatItem({
    required this.label,
    required this.value,
    required this.accentColor,
    this.profileColorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = profileColorScheme?.surfaceContainerHighest ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    
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
            const SizedBox(height: 3),
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
