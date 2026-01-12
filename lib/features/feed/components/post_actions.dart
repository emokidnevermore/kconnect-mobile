/// Компонент действий поста с лайками, репостами и комментариями
///
/// Отображает кнопки взаимодействия с постом: лайк, репост, комментарии.
/// Показывает статистику взаимодействий и обрабатывает нажатия.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/widgets/profile_accent_color_provider.dart';
import 'post_comments_preview.dart';
import 'post_constants.dart';

/// Компонент действий поста (лайк, репост, комментарии)
class PostActions extends StatelessWidget {
  final bool isLiked;
  final int likesCount;
  final int originalLikesCount;
  final Map<String, dynamic>? lastComment;
  final int commentsCount;
  final Function()? onLikePressed;
  final Function()? onRepostPressed;
  final Function()? onCommentsPressed;
  final bool isLikeProcessing;

  const PostActions({
    super.key,
    this.isLiked = false,
    this.likesCount = 0,
    this.originalLikesCount = 0,
    this.lastComment,
    this.commentsCount = 0,
    this.onLikePressed,
    this.onRepostPressed,
    this.onCommentsPressed,
    this.isLikeProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            // Лайк с анимацией
            Flexible(
              flex: 0,
              child: _AnimatedLikeButton(
                isLiked: isLiked,
                likesCount: likesCount,
                isProcessing: isLikeProcessing,
                onTap: onLikePressed,
              ),
            ),
            const SizedBox(width: 12),
            // Комментарии
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PostConstants.borderRadius),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.23), width: 1),
                ),
                child: PostCommentsPreview(
                  lastComment: lastComment,
                  totalComments: commentsCount,
                  onTap: onCommentsPressed,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Репост с анимацией
            Flexible(
              flex: 0,
              child: _AnimatedRepostButton(
                onTap: onRepostPressed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Анимированная кнопка лайка с spring эффектом
class _AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final int likesCount;
  final bool isProcessing;
  final VoidCallback? onTap;

  const _AnimatedLikeButton({
    required this.isLiked,
    required this.likesCount,
    this.isProcessing = false,
    this.onTap,
  });

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _colorAnimation;
  int _displayedCount = 0;

  @override
  void initState() {
    super.initState();
    _displayedCount = widget.likesCount;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale animation with spring effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
    ]).animate(_animationController);

    // Color animation
    _colorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set initial state
    if (widget.isLiked) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update count with animation if changed
    if (widget.likesCount != oldWidget.likesCount) {
      _displayedCount = widget.likesCount;
    }
    
    // Update animation state if liked status changed externally
    if (widget.isLiked != oldWidget.isLiked) {
      if (widget.isLiked) {
        _animationController.forward();
        HapticFeedback.lightImpact();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _handleTap() {
    if (widget.isProcessing || widget.onTap == null) return;

    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Trigger animation immediately
    final willBeLiked = !widget.isLiked;
    if (willBeLiked) {
      _animationController.forward(from: 0.0);
    } else {
      _animationController.reverse(from: 1.0);
    }

    // Call the callback
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.isProcessing ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Interpolate color between unliked and liked state
          final likedColor = context.profileAccentColor;
          final unlikedColor = colorScheme.onSurfaceVariant;
          final animatedColor = Color.lerp(
            unlikedColor,
            likedColor,
            _colorAnimation.value,
          ) ?? unlikedColor;

          // Interpolate between border and filled icon
          final icon = _colorAnimation.value > 0.5
              ? Icons.favorite
              : Icons.favorite_border;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  icon,
                  size: PostConstants.actionIconSize,
                  color: animatedColor,
                ),
              ),
              const SizedBox(width: 4),
              // Animated counter
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.5),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '$_displayedCount',
                  key: ValueKey(_displayedCount),
                  style: AppTextStyles.postStats.copyWith(
                    fontWeight: FontWeight.normal,
                    color: animatedColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Анимированная кнопка репоста с rotation и scale эффектом
class _AnimatedRepostButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _AnimatedRepostButton({
    this.onTap,
  });

  @override
  State<_AnimatedRepostButton> createState() => _AnimatedRepostButtonState();
}

class _AnimatedRepostButtonState extends State<_AnimatedRepostButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Rotation animation (0° → 360°)
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0, // 1.0 = 360 degrees
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Scale animation (1.0 → 1.2 → 1.0)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60.0,
      ),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Trigger animation
    _animationController.forward(from: 0.0).then((_) {
      _animationController.reverse(from: 1.0);
    });
    
    // Execute callback
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159, // Convert to radians
              child: Icon(
                Icons.refresh,
                size: PostConstants.actionIconSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}
