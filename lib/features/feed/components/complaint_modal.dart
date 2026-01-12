import 'package:flutter/material.dart';
import '../../../theme/app_text_styles.dart';
import '../../../services/storage_service.dart';
import '../domain/models/complaint.dart';

/// Красивое модальное окно для создания жалобы на пост с анимациями
///
/// Позволяет пользователю выбрать тип жалобы с плавными анимациями,
/// ввести дополнительную информацию при необходимости.
/// Кнопка отправки находится внизу и активируется при выборе типа жалобы.
class ComplaintModal extends StatefulWidget {
  /// ID поста для жалобы
  final int postId;

  /// Функция обратного вызова при успешной отправке жалобы
  final Function(ComplaintResponse)? onComplaintSubmitted;

  const ComplaintModal({
    super.key,
    required this.postId,
    this.onComplaintSubmitted,
  });

  /// Показать модальное окно жалобы
  static Future<void> show(
    BuildContext context, {
    required int postId,
    Function(ComplaintResponse)? onComplaintSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => ComplaintModal(
        postId: postId,
        onComplaintSubmitted: onComplaintSubmitted,
      ),
    );
  }

  @override
  State<ComplaintModal> createState() => _ComplaintModalState();
}

class _ComplaintModalState extends State<ComplaintModal> with TickerProviderStateMixin {
  ComplaintType? _selectedComplaintType;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Получить цвет фона меню в зависимости от наличия фонового изображения
  Color _getMenuBackgroundColor(BuildContext context) {
    final hasBackground = StorageService.appBackgroundPathNotifier.value?.isNotEmpty ?? false;
    return hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.95)
        : Theme.of(context).colorScheme.surfaceContainerLow;
  }

  /// Обработчик выбора типа жалобы
  void _onComplaintTypeSelected(ComplaintType complaintType) {
    setState(() {
      _selectedComplaintType = complaintType;
    });
  }

  /// Отправить жалобу на сервер
  Future<void> _submitComplaint() async {
    if (_selectedComplaintType == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? description;

      if (_selectedComplaintType == ComplaintType.other) {
        description = _customReasonController.text.trim();
        if (description.isEmpty) {
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      }

      // Имитация успешной отправки
      await Future.delayed(const Duration(seconds: 1));

      final mockResponse = ComplaintResponse(
        complaintId: 123,
        message: 'Жалоба создана и отправлена модераторам',
        success: true,
        ticketId: 456,
      );

      // Вызываем callback
      widget.onComplaintSubmitted?.call(mockResponse);

      // Закрываем модальное окно с анимацией
      await _animationController.reverse();
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Обрабатываем ошибку
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: _getMenuBackgroundColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar с анимацией
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Заголовок
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Пожаловаться',
                          style: AppTextStyles.h3.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final capturedContext = context;
                            await _animationController.reverse();
                            if (mounted) {
                              // ignore: use_build_context_synchronously
                              Navigator.of(capturedContext).pop();
                            }
                          },
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Описание
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Выберите причину жалобы. Ваша жалоба поможет сделать сообщество лучше.',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Список типов жалоб с анимациями
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: ComplaintType.values.length,
                      itemBuilder: (context, index) {
                        final complaintType = ComplaintType.values[index];
                        final isSelected = _selectedComplaintType == complaintType;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                complaintType.icon,
                                size: 20,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              complaintType.displayName,
                              style: AppTextStyles.body.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: complaintType.description != null
                                ? Text(
                                    complaintType.description!,
                                    style: AppTextStyles.body.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            onTap: _isSubmitting ? null : () => _onComplaintTypeSelected(complaintType),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  // Поле для ввода причины при выборе "Другое"
                  if (_selectedComplaintType == ComplaintType.other)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _customReasonController,
                        decoration: InputDecoration(
                          hintText: 'Опишите причину жалобы подробнее...',
                          hintStyle: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        maxLines: 3,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),

                  // Кнопка отправки внизу
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_selectedComplaintType != null &&
                                !_isSubmitting &&
                                (_selectedComplaintType != ComplaintType.other ||
                                 _customReasonController.text.trim().isNotEmpty))
                            ? _submitComplaint
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Отправить жалобу',
                                style: AppTextStyles.button.copyWith(
                                  color: _selectedComplaintType != null &&
                                          (_selectedComplaintType != ComplaintType.other ||
                                           _customReasonController.text.trim().isNotEmpty)
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
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
}
