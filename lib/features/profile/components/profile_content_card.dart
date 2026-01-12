/// Основная карточка контента профиля
///
/// Содержит информацию "О себе", аватар со статистикой и статус пользователя.
/// Объединяет все основные компоненты профиля в единую карточку.
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_text_styles.dart';
import '../../../services/api_client/dio_client.dart';
import '../domain/models/user_profile.dart';
import '../domain/models/following_info.dart';
import '../presentation/blocs/profile_state.dart';
import 'profile_avatar_stats.dart';
import 'profile_status_display.dart';
import 'profile_social_links.dart';

/// Виджет основной карточки контента профиля
///
/// Комплексный компонент, объединяющий все ключевые элементы профиля:
/// описание, аватар со статистикой, статус пользователя в единой карточке.
class ProfileContentCard extends StatefulWidget {
  final UserProfile profile;
  final FollowingInfo? followingInfo;
  final ProfileLoaded profileState;
  final Color accentColor;
  final VoidCallback? onEditPressed;
  final VoidCallback onFollowPressed;
  final VoidCallback onUnfollowPressed;
  final bool hasProfileBackground;
  final ColorScheme? profileColorScheme;

  const ProfileContentCard({
    super.key,
    required this.profile,
    required this.followingInfo,
    required this.profileState,
    required this.accentColor,
    required this.onEditPressed,
    required this.onFollowPressed,
    required this.onUnfollowPressed,
    required this.hasProfileBackground,
    this.profileColorScheme,
  });

  @override
  State<ProfileContentCard> createState() => _ProfileContentCardState();
}

class _ProfileContentCardState extends State<ProfileContentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
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
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Builder(
            builder: (context) {
              final cardColor = widget.hasProfileBackground
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : (widget.profileColorScheme?.surfaceContainerLow ?? Theme.of(context).colorScheme.surfaceContainerLow);
              
              return Card(
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner with name and username
                    _buildBannerSection(context),
                    
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar and Stats
                          ProfileAvatarStats(
                            profile: widget.profile,
                            followingInfo: widget.followingInfo,
                            isOwnProfile: widget.profileState.isOwnProfile,
                            isSkeleton: widget.profileState.isSkeleton,
                            accentColor: widget.accentColor,
                            onEditPressed: widget.onEditPressed,
                            onFollowPressed: widget.onFollowPressed,
                            onUnfollowPressed: widget.onUnfollowPressed,
                            hideActionButton: true,
                            profileColorScheme: widget.profileColorScheme,
                          ),
                      
                      // About section
                      if (widget.profile.about?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        Text(
                          widget.profile.about!,
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                      
                      // Status
                      if (widget.profile.statusText?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        ProfileStatusDisplay(statusText: widget.profile.statusText!),
                      ],
                      
                          // Social Links
                          if (widget.profile.socials.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ProfileSocialLinks(
                              socials: widget.profile.socials,
                              accentColor: widget.accentColor,
                              profileColorScheme: widget.profileColorScheme,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: DioClient().getImageAuthHeaders(),
      builder: (context, snapshot) {
        return Container(
          height: 160,
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.3),
            image: widget.profile.bannerUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(
                      widget.profile.bannerUrl!,
                      headers: snapshot.data,
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        );
      },
    );
  }
}
