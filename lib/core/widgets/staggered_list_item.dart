import 'package:flutter/material.dart';

/// Wrapper для элементов списка с staggered animation
class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Curve curve;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
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

    // Ограничиваем количество анимируемых элементов, чтобы избежать проблем при больших списках
    // Анимируем только первые 20 элементов, остальные показываем сразу
    if (widget.index > 20) {
      _controller.value = 1.0; // Сразу показываем элемент
      _fadeAnimation = AlwaysStoppedAnimation(1.0);
      _slideAnimation = AlwaysStoppedAnimation(Offset.zero);
    } else {
      final delay = widget.index * widget.delay.inMilliseconds;
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
            curve: widget.curve,
          ),
        ),
      );

      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            intervalStart,
            intervalEnd,
            curve: widget.curve,
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
        child: widget.child,
      ),
    );
  }
}
