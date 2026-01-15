/// Переиспользуемый компонент overlay для отображения состояния сохранения
///
/// Material Design 3 inspired overlay с плавными анимациями и современным дизайном.
/// Поддерживает состояния: loading, success, error.
library;

import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';

/// Состояния overlay сохранения
enum SavingOverlayState {
  /// Показывать индикатор загрузки
  saving,

  /// Показывать иконку успеха
  success,

  /// Показывать иконку ошибки
  error,
}

/// Overlay для отображения состояния сохранения с Material Design 3 стилем
///
/// Предоставляет единообразный интерфейс для отображения процессов сохранения
/// в различных экранах приложения.
class SavingOverlay extends StatefulWidget {
  final SavingOverlayState state;
  final String? customMessage;

  const SavingOverlay({
    super.key,
    required this.state,
    this.customMessage,
  });

  @override
  State<SavingOverlay> createState() => _SavingOverlayState();
}

class _SavingOverlayState extends State<SavingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _bounceController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    // Контроллер для плавного появления/исчезновения
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Контроллер для масштабирования иконки
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Контроллер для bounce анимации
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.bounceOut),
    );

    // Запускаем анимации
    _fadeController.forward();
    _scaleController.forward();
    if (widget.state != SavingOverlayState.saving) {
      _bounceController.forward();
    }
  }

  @override
  void didUpdateWidget(SavingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state != widget.state) {
      // При изменении состояния перезапускаем bounce анимацию
      if (widget.state != SavingOverlayState.saving) {
        _bounceController.reset();
        _bounceController.forward();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  String _getMessage() {
    if (widget.customMessage != null) return widget.customMessage!;

    switch (widget.state) {
      case SavingOverlayState.saving:
        return 'Сохранение...';
      case SavingOverlayState.success:
        return 'Успех!';
      case SavingOverlayState.error:
        return 'Ошибка';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _bounceAnimation]),
      builder: (context, child) {
        return Container(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4 * _fadeAnimation.value),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Контейнер с иконкой
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 1),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 1),
                          blurRadius: 50,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildIcon(context),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Текст с анимацией появления
                  FadeTransition(
                    opacity: _bounceAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _bounceController,
                        curve: Curves.easeOutCubic,
                      )),
                      child: Text(
                        _getMessage(),
                        style: AppTextStyles.h3.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Дополнительное сообщение для ошибки
                  if (widget.state == SavingOverlayState.error)
                    FadeTransition(
                      opacity: _bounceAnimation,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Попробуйте еще раз',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (widget.state) {
      case SavingOverlayState.saving:
        return CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        );

      case SavingOverlayState.success:
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            color: colorScheme.onPrimaryContainer,
            size: 48,
          ),
        );

      case SavingOverlayState.error:
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            color: colorScheme.onErrorContainer,
            size: 48,
          ),
        );
    }
  }
}
