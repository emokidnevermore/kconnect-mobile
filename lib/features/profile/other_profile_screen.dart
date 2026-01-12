import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/app_text_styles.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_bloc.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_event.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_state.dart';
import 'components/profile_background.dart';
import 'components/profile_content_card.dart';
import 'components/profile_posts_section.dart';
import 'components/swipe_pop_container.dart';
import 'utils/profile_color_utils.dart';
import 'utils/profile_cache_utils.dart';
import '../../core/widgets/profile_accent_color_provider.dart';
import 'domain/models/following_info.dart';
import 'domain/models/user_profile.dart';

class OtherProfileScreen extends StatefulWidget {
  final String username;

  const OtherProfileScreen({super.key, required this.username});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> with AutomaticKeepAliveClientMixin, ProfileCacheManager {
  late ProfileBloc _profileBloc;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileBloc = context.read<ProfileBloc>();
  }

  @override
  void initState() {
    super.initState();
    initCacheManager();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileBloc>().add(PushProfileStackEvent(widget.username));
      }
    });
  }

  @override
  void dispose() {
    _profileBloc.add(PopProfileStackEvent());
    disposeCacheManager();
    super.dispose();
  }

  @override
  void onAppResumed() {
    _checkCacheAndRefreshIfNeeded();
  }

  void _checkCacheAndRefreshIfNeeded() async {
    try {
      final shouldRefresh = await shouldRefreshCache(_getPostsCount(), null);
      if (shouldRefresh) {
        _profileBloc.add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      // Ошибка
    }
  }

  int? _getPostsCount() {
    final currentState = _profileBloc.state;
    if (currentState is ProfileLoaded) {
      return currentState.posts.length + (currentState.pinnedPost != null ? 1 : 0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {

      },
      child: BlocBuilder<ProfileBloc, ProfileState>(
        buildWhen: (previous, current) {
          if (current.isLoaded) {
            final currentLoaded = current.asLoaded!;
            final previousLoaded = previous.isLoaded ? previous.asLoaded! : null;
            
            final currentMatches = currentLoaded.profile.username == widget.username && 
                                  currentLoaded.isValidForUsername(widget.username);
            final previousMatches = previousLoaded != null && 
                                   previousLoaded.profile.username == widget.username && 
                                   previousLoaded.isValidForUsername(widget.username);
            
            if (currentMatches && !previousMatches) {
              return true;
            }
            if (currentMatches && previousMatches) {
              return previous != current;
            }
            return false;
          }
          return true;
        },
        builder: (context, state) {
          if (state.isLoaded) {
            final loadedState = state.asLoaded!;
  
            if (!loadedState.isValidForUsername(widget.username)) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildProfileView(loadedState);
          }

          if (state.isError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.asError!.message,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<ProfileBloc>().add(PushProfileStackEvent(widget.username));
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }


  Widget _buildProfileView(ProfileLoaded profileState) {
    final profile = profileState.profile;
    final accentColor = ProfileColorUtils.getProfileAccentColor(profile, context);
    final profileColorScheme = ProfileColorUtils.createProfileColorScheme(accentColor);

    final scrollView = ProfileAccentColorProvider(
      accentColor: accentColor,
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<ProfileBloc>().add(RefreshProfileEvent());
        },
        color: accentColor,
        child: CustomScrollView(
          slivers: [
            // Отступ сверху под хедер
            const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
            SliverToBoxAdapter(
              child: ProfileContentCard(
                profile: profile,
                followingInfo: profileState.followingInfo,
                profileState: profileState,
                accentColor: accentColor,
                onEditPressed: null,
                onFollowPressed: () => context.read<ProfileBloc>().add(FollowUserEvent(profile.username)),
                onUnfollowPressed: () => context.read<ProfileBloc>().add(UnfollowUserEvent(profile.username)),
                hasProfileBackground: profile.profileBackgroundUrl != null && profile.profileBackgroundUrl!.isNotEmpty,
                profileColorScheme: profileColorScheme,
              ),
            ),
            ProfilePostsSection(
              profileState: profileState,
              accentColor: accentColor,
              hasProfileBackground: profile.profileBackgroundUrl != null && profile.profileBackgroundUrl!.isNotEmpty,
              profileColorScheme: profileColorScheme,
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );

    final screenWidget = Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Бекграунд профиля без лишних отступов
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: ProfileBackground(
                backgroundUrl: profile.profileBackgroundUrl,
                profileColorScheme: profileColorScheme,
              ),
            ),
          ),
          SafeArea(
            bottom: true,
            child: ColoredBox(
              color: Colors.transparent,
              child: scrollView,
            ),
          ),
          // Хедер поверх всего контента
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: true,
              bottom: false,
              child: _OtherProfileHeader(
                username: profile.username,
                accentColor: accentColor,
                onBackPressed: () => Navigator.of(context).pop(),
                hasProfileBackground: profile.profileBackgroundUrl != null && profile.profileBackgroundUrl!.isNotEmpty,
                profileColorScheme: profileColorScheme,
              ),
            ),
          ),
          // Нижняя панель с кнопками (на той же высоте что и таб бар)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: true,
              child: _buildBottomActionBar(profileState, accentColor, context),
            ),
          ),
        ],
      ),
    );

    return SwipePopContainer(
      child: screenWidget,
    );
  }

  /// Определяет, нужен ли черный текст/иконка на данном фоне
  /// Использует более низкий порог для учета кремовых, желтых и других светлых цветов
  bool _shouldUseBlackText(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.55;
  }

  Widget _buildBottomActionBar(ProfileLoaded profileState, Color accentColor, BuildContext context) {
    // Не показываем кнопки для своего профиля
    final isSelf = profileState.isOwnProfile || profileState.followingInfo?.isSelf == true;
    if (isSelf) {
      return const SizedBox.shrink();
    }

    final followingInfo = profileState.followingInfo;
    final profile = profileState.profile;
    final shouldUseBlackIcon = _shouldUseBlackText(accentColor);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Анимированная кнопка подписки/отписки/друзья
            Expanded(
              child: _AnimatedFollowButton(
                followingInfo: followingInfo,
                profile: profile,
                accentColor: accentColor,
                isOwnProfile: profileState.isOwnProfile,
                onFollowPressed: () => context.read<ProfileBloc>().add(FollowUserEvent(profile.username)),
                onUnfollowPressed: () => context.read<ProfileBloc>().add(UnfollowUserEvent(profile.username)),
              ),
            ),
            const SizedBox(width: 12),
            // Круглая кнопка сообщения
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  // TODO: Реализовать логику отправки сообщения
                },
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: shouldUseBlackIcon ? Colors.black : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// Анимированная кнопка Follow/Unfollow
class _AnimatedFollowButton extends StatefulWidget {
  final FollowingInfo? followingInfo;
  final UserProfile profile;
  final Color accentColor;
  final bool isOwnProfile;
  final VoidCallback onFollowPressed;
  final VoidCallback onUnfollowPressed;

  const _AnimatedFollowButton({
    required this.followingInfo,
    required this.profile,
    required this.accentColor,
    this.isOwnProfile = false,
    required this.onFollowPressed,
    required this.onUnfollowPressed,
  });

  @override
  State<_AnimatedFollowButton> createState() => _AnimatedFollowButtonState();
}

class _AnimatedFollowButtonState extends State<_AnimatedFollowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Более мягкая анимация без сильного сплющивания
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.97)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.97, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60.0,
      ),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AnimatedFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate when following status changes
    if (widget.followingInfo?.currentUserFollows != 
        oldWidget.followingInfo?.currentUserFollows) {
      _animationController.forward(from: 0.0).then((_) {
        _animationController.reverse();
      });
      
      // Show success briefly after follow
      if (widget.followingInfo?.currentUserFollows == true && 
          oldWidget.followingInfo?.currentUserFollows == false) {
        setState(() {
          _showSuccess = true;
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _showSuccess = false;
            });
          }
        });
      }
    }
  }

  void _handlePress() {
    // Не выполняем действие, если это свой профиль
    final isSelf = widget.followingInfo?.isSelf ?? widget.isOwnProfile;
    if (isSelf) {
      return;
    }
    
    if (widget.followingInfo == null) return;
    
    final isFollowing = widget.followingInfo!.currentUserFollows;
    final isFriend = widget.followingInfo!.currentUserIsFriend;
    
    if (isFriend || (widget.followingInfo!.followsBack && isFollowing)) {
      return; // No action for friends
    }
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Trigger animation
    _animationController.forward(from: 0.0).then((_) {
      _animationController.reverse();
    });
    
    // Execute action
    if (isFollowing) {
      widget.onUnfollowPressed();
    } else {
      widget.onFollowPressed();
    }
  }

  String _getButtonText() {
    // Проверяем, является ли это свой профиль (используем isOwnProfile как fallback)
    final isSelf = widget.followingInfo?.isSelf ?? widget.isOwnProfile;
    
    if (isSelf) {
      return 'Это вы';
    }

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

  Color _getButtonColor() {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Нейтральный цвет для своего профиля
    final isSelf = widget.followingInfo?.isSelf ?? widget.isOwnProfile;
    if (isSelf) {
      return colorScheme.onSurfaceVariant;
    }
    
    if (widget.followingInfo == null) {
      return colorScheme.onSurfaceVariant;
    }

    final isFollowing = widget.followingInfo!.currentUserFollows;
    final followsBack = widget.followingInfo!.followsBack;

    if ((followsBack && isFollowing) || widget.followingInfo!.currentUserIsFriend) {
      return const Color(0xFF4CAF50); // Green for friends
    } else if (followsBack && !isFollowing) {
      return colorScheme.onSurfaceVariant;
    } else if (isFollowing) {
      return colorScheme.onSurfaceVariant;
    } else {
      return widget.accentColor;
    }
  }

  bool _shouldUseBlackText(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.55;
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _getButtonText();
    final buttonColor = _getButtonColor();
    final shouldUseBlackText = _shouldUseBlackText(buttonColor);
    final isSelf = widget.followingInfo?.isSelf ?? widget.isOwnProfile;
    final isDisabled = isSelf ||
        widget.followingInfo?.currentUserIsFriend == true ||
        (widget.followingInfo?.followsBack == true && 
         widget.followingInfo?.currentUserFollows == true);

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Используем только вертикальное масштабирование для мягкой анимации
          return Transform.scale(
            scaleX: 1.0, // Не масштабируем по ширине
            scaleY: _scaleAnimation.value,
            alignment: Alignment.center,
            child: SizedBox(
              height: 50, // Фиксированная высота как у таб бара
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  minimumSize: const Size(0, 50), // Минимальная высота 50
                  backgroundColor: buttonColor,
                ),
                onPressed: isDisabled ? null : _handlePress,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _showSuccess
                    ? Icon(
                        Icons.check,
                        key: const ValueKey('check'),
                        color: shouldUseBlackText
                            ? Colors.black
                            : Theme.of(context).colorScheme.onSurface,
                      )
                    : Text(
                        buttonText,
                        key: ValueKey(buttonText),
                        style: TextStyle(
                          color: shouldUseBlackText
                              ? Colors.black
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

/// Прозрачный хедер для экрана чужого профиля
class _OtherProfileHeader extends StatelessWidget {
  final String username;
  final Color accentColor;
  final VoidCallback onBackPressed;
  final bool hasProfileBackground;
  final ColorScheme? profileColorScheme;

  const _OtherProfileHeader({
    required this.username,
    required this.accentColor,
    required this.onBackPressed,
    required this.hasProfileBackground,
    this.profileColorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем цвет карточки на основе логики профиля
    final cardColor = hasProfileBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : (profileColorScheme?.surfaceContainerLow ?? Theme.of(context).colorScheme.surfaceContainerLow);
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // Кнопка назад в стеклянной карточке
          Card(
            margin: EdgeInsets.zero,
            color: cardColor,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onBackPressed,
                    icon: Icon(
                      Icons.arrow_back,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '@$username',
                    style: AppTextStyles.postAuthor.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
