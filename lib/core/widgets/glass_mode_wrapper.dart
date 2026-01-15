/// Виджет-обертка для применения различных режимов стекла
///
/// Оборачивает дочерний виджет в зависимости от выбранного режима:
/// - glass: полный эффект жидкого стекла
/// - fakeGlass: легковесный эффект стекла
/// - solid: темный фон с прозрачностью
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../constants/tab_bar_glass_mode.dart';
import '../../services/storage_service.dart';

/// Виджет-обертка для применения режима стекла
class GlassModeWrapper extends StatefulWidget {
  /// Дочерний виджет
  final Widget child;

  /// Радиус скругления углов
  final double borderRadius;

  /// Настройки стекла (используются только для glass и fakeGlass режимов)
  final LiquidGlassSettings? settings;

  const GlassModeWrapper({
    super.key,
    required this.child,
    required this.borderRadius,
    this.settings,
  });

  @override
  State<GlassModeWrapper> createState() => _GlassModeWrapperState();
}

class _GlassModeWrapperState extends State<GlassModeWrapper> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся на изменения через ValueListenableBuilder
    return ValueListenableBuilder<TabBarGlassMode>(
      valueListenable: StorageService.tabBarGlassModeNotifier,
      builder: (context, mode, child) {
        switch (mode) {
          case TabBarGlassMode.glass:
            return _buildGlassMode();
          case TabBarGlassMode.fakeGlass:
            return _buildFakeGlassMode();
          case TabBarGlassMode.solid:
            return _buildSolidMode();
        }
      },
    );
  }

  Widget _buildGlassMode() {
    final settings = widget.settings ??
        const LiquidGlassSettings(
          thickness: 15,
          glassColor: Color(0x33FFFFFF),
          lightIntensity: 1.5,
          chromaticAberration: 1,
          saturation: 1.1,
          ambientStrength: 1,
          blur: 4,
          refractiveIndex: 1.8,
        );

    return LiquidGlassLayer(
      settings: settings,
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: widget.borderRadius),
        child: widget.child,
      ),
    );
  }

  Widget _buildFakeGlassMode() {
    final settings = widget.settings ??
        const LiquidGlassSettings(
          blur: 4,
          glassColor: Color(0x33FFFFFF),
        );

    return FakeGlass(
      shape: LiquidRoundedSuperellipse(borderRadius: widget.borderRadius),
      settings: settings,
      child: widget.child,
    );
  }

  Widget _buildSolidMode() {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                blurRadius: 1,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
