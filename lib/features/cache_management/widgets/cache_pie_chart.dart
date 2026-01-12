/// Виджет круговой диаграммы для отображения использования кэша
///
/// Отображает распределение кэша по категориям в виде круговой диаграммы
/// с анимацией и интерактивностью.
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../services/cache/cache_category.dart';
import '../../../core/utils/cache_size_calculator.dart';

/// Виджет круговой диаграммы кэша
class CachePieChart extends StatefulWidget {
  /// Размеры кэша по категориям
  final Map<CacheCategory, int> cacheSizes;

  /// Общий размер кэша
  final int totalSize;

  const CachePieChart({
    super.key,
    required this.cacheSizes,
    required this.totalSize,
  });

  @override
  State<CachePieChart> createState() => _CachePieChartState();
}

class _CachePieChartState extends State<CachePieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(CachePieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheSizes != widget.cacheSizes) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (widget.totalSize == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Кэш пуст',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _PieChartPainter(
            cacheSizes: widget.cacheSizes,
            totalSize: widget.totalSize,
            animationValue: _animation.value,
            colorScheme: colorScheme,
          ),
        );
      },
    );
  }
}

/// CustomPainter для отрисовки круговой диаграммы
class _PieChartPainter extends CustomPainter {
  final Map<CacheCategory, int> cacheSizes;
  final int totalSize;
  final double animationValue;
  final ColorScheme colorScheme;

  _PieChartPainter({
    required this.cacheSizes,
    required this.totalSize,
    required this.animationValue,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    
    double startAngle = -math.pi / 2; // Начинаем сверху

    // Сортируем категории по размеру (от большего к меньшему)
    final sortedCategories = cacheSizes.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCategories) {
      final category = entry.key;
      final size = entry.value;
      final sweepAngle = (size / totalSize) * 2 * math.pi * animationValue;

      final paint = Paint()
        ..color = category.getColor(colorScheme)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Рисуем центр (пустой круг)
    final centerPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, centerPaint);

    // Рисуем текст в центре
    final textPainter = TextPainter(
      text: TextSpan(
        text: CacheSizeCalculator.formatBytes(totalSize),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.cacheSizes != cacheSizes ||
        oldDelegate.animationValue != animationValue;
  }
}
