/// Анимированная кнопка лайка для мини-плеера с spring эффектом
///
/// Внутренний компонент для ExpandedPlayer
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Анимированная кнопка лайка для мини-плеера с spring эффектом
class AnimatedMiniPlayerLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback? onTap;

  const AnimatedMiniPlayerLikeButton({
    super.key,
    required this.isLiked,
    this.onTap,
  });

  @override
  State<AnimatedMiniPlayerLikeButton> createState() => _AnimatedMiniPlayerLikeButtonState();
}

class _AnimatedMiniPlayerLikeButtonState extends State<AnimatedMiniPlayerLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _colorAnimation;

  @override
  void initState() {
    super.initState();

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
  void didUpdateWidget(AnimatedMiniPlayerLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation state if liked status changed externally
    if (widget.isLiked != oldWidget.isLiked) {
      if (widget.isLiked) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _handleTap() {
    if (widget.onTap == null) return;

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
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Interpolate color between unliked and liked state
          final likedColor = Theme.of(context).colorScheme.primary;
          final unlikedColor = Theme.of(context).colorScheme.onSurfaceVariant;
          final animatedColor = Color.lerp(
            unlikedColor,
            likedColor,
            _colorAnimation.value,
          ) ?? unlikedColor;

          // Interpolate between border and filled icon
          final icon = _colorAnimation.value > 0.5
              ? Icons.favorite
              : Icons.favorite_border;

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              icon,
              size: 16,
              color: animatedColor,
            ),
          );
        },
      ),
    );
  }
}
