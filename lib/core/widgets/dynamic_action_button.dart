/// Динамическая кнопка действий для навигационной панели
///
/// Компонент кнопки действий, которая изменяется в зависимости
/// от текущего таба и состояния приложения
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'glass_mode_wrapper.dart';

/// Динамическая кнопка действий
class DynamicActionButton extends StatelessWidget {
  /// Размер кнопки
  final double size;

  /// Колбэк при нажатии
  final VoidCallback? onPressed;

  /// Иконка для кнопки
  final IconData icon;

  const DynamicActionButton({
    super.key,
    this.size = 50.0,
    this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GlassModeWrapper(
        borderRadius: 25,
        settings: const LiquidGlassSettings(
          thickness: 15,
          glassColor: Color(0x33FFFFFF),
          lightIntensity: 1.5,
          chromaticAberration: 1,
          saturation: 1.1,
          ambientStrength: 1,
          blur: 4,
          refractiveIndex: 1.8,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
