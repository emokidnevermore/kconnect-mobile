/// Компонент редактирования статуса профиля
///
/// Предоставляет интерактивное поле для ввода и редактирования статуса пользователя
/// с выбором иконки и цветом фона как у статуса.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/features/profile/domain/models/subscription_info.dart';

// Класс для хранения результата парсинга статуса
class ParsedStatusData {
  final String? icon;
  final String cleanText;

  const ParsedStatusData({this.icon, required this.cleanText});
}

/// Виджет секции редактирования статуса
class StatusEditSection extends StatefulWidget {
  final TextEditingController controller;
  final String? statusColor;
  final VoidCallback? onPickStatusColor;
  final SubscriptionInfo? subscription;

  const StatusEditSection({
    super.key,
    required this.controller,
    this.statusColor,
    this.onPickStatusColor,
    this.subscription,
  });

  @override
  State<StatusEditSection> createState() => _StatusEditSectionState();
}

class _StatusEditSectionState extends State<StatusEditSection> {
  String? _selectedIcon;
  late TextEditingController _displayController;
  bool _isInternalChange = false;

  // Список доступных иконок статуса
  final List<String> _availableIcons = [
    'info',
    'cloud',
    'minion',
    'heart',
    'star',
    'music',
    'location',
    'cake',
    'chat',
  ];

  @override
  void initState() {
    super.initState();
    // Парсим иконку и очищаем текст от тега при инициализации
    final parsedData = _parseIconAndCleanText(widget.controller.text);
    _selectedIcon = parsedData.icon;
    _displayController = TextEditingController(text: parsedData.cleanText);
    // Слушаем изменения контроллера отображения
    _displayController.addListener(_onDisplayTextChanged);
    // Слушаем изменения основного контроллера для внешних изменений
    widget.controller.addListener(_onMainControllerChanged);
  }

  @override
  void didUpdateWidget(StatusEditSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если текст в основном контроллере изменился (например, после загрузки данных из API),
    // нужно перепарсить его и обновить локальное состояние
    if (widget.controller.text != oldWidget.controller.text) {
      final parsedData = _parseIconAndCleanText(widget.controller.text);
      setState(() {
        _selectedIcon = parsedData.icon;
        _displayController.text = parsedData.cleanText;
      });
    }
  }

  @override
  void dispose() {
    _displayController.removeListener(_onDisplayTextChanged);
    widget.controller.removeListener(_onMainControllerChanged);
    _displayController.dispose();
    super.dispose();
  }

  ParsedStatusData _parseIconAndCleanText(String fullText) {
    if (fullText.startsWith('{') && fullText.contains('}')) {
      final closeBraceIndex = fullText.indexOf('}');
      if (closeBraceIndex > 1) {
        final iconName = fullText.substring(1, closeBraceIndex);
        final cleanText = fullText.substring(closeBraceIndex + 1).trim();
        return ParsedStatusData(icon: iconName, cleanText: cleanText);
      }
    }
    return ParsedStatusData(icon: null, cleanText: fullText);
  }

  void _onMainControllerChanged() {
    // Когда текст в основном контроллере меняется извне (например, при загрузке данных),
    // перепарсиваем его и обновляем локальное состояние
    if (!_isInternalChange) {
      final parsedData = _parseIconAndCleanText(widget.controller.text);
      setState(() {
        _selectedIcon = parsedData.icon;
        _displayController.text = parsedData.cleanText;
      });
    }
  }

  void _onDisplayTextChanged() {
    // Когда пользователь редактирует текст в поле отображения,
    // формируем полный текст с тегом иконки для основного контроллера
    _isInternalChange = true;
    final currentDisplayText = _displayController.text;
    final iconTag = _selectedIcon != null ? '{$_selectedIcon}' : '';
    // Добавляем пробел между тегом иконки и текстом, если есть и иконка и текст
    final separator = _selectedIcon != null && currentDisplayText.isNotEmpty ? ' ' : '';
    final fullText = iconTag + separator + currentDisplayText;

    if (widget.controller.text != fullText) {
      widget.controller.text = fullText;
    }
    _isInternalChange = false;
  }

  void _selectIcon(String iconName) {
    setState(() {
      if (_selectedIcon == iconName) {
        // Убираем иконку если она уже выбрана
        _selectedIcon = null;
      } else {
        // Выбираем новую иконку
        _selectedIcon = iconName;
      }
      // Обновляем основной контроллер с новым текстом
      _updateMainControllerText();
    });
  }

  void _updateMainControllerText() {
    final currentDisplayText = _displayController.text;
    final iconTag = _selectedIcon != null ? '{$_selectedIcon}' : '';
    // Добавляем пробел между тегом иконки и текстом, если есть и иконка и текст
    final separator = _selectedIcon != null && currentDisplayText.isNotEmpty ? ' ' : '';
    final fullText = iconTag + separator + currentDisplayText;

    if (widget.controller.text != fullText) {
      widget.controller.text = fullText;
    }
  }

  Color _getBackgroundColor() {
    if (widget.statusColor == null || widget.statusColor!.isEmpty) {
      return const Color(0xFFFFFFFF);
    }

    try {
      final colorStr = widget.statusColor!.startsWith('#')
          ? widget.statusColor!.substring(1)
          : widget.statusColor!;

      final colorInt = int.parse(colorStr, radix: 16);
      if (colorStr.length == 6) {
        return Color(colorInt | 0xFF000000);
      } else if (colorStr.length == 8) {
        return Color(colorInt);
      } else {
        return const Color(0xFFFFFFFF);
      }
    } catch (e) {
      return const Color(0xFFFFFFFF);
    }
  }

  Color _getTextColor(Color backgroundColor) {
    final isBgLight = backgroundColor.computeLuminance() > 0.85;
    return isBgLight ? Colors.black : const Color(0xFF1C1B1F); // AppColors.textPrimary
  }

  String? _getSelectedIconData() {
    if (_selectedIcon == null) return null;
    return _getStatusIcon(_selectedIcon!);
  }

  String? _getStatusIcon(String iconName) {
    switch (iconName) {
      case 'info':
        return 'lib/assets/icons/status_icons/info.svg';
      case 'cloud':
        return 'lib/assets/icons/status_icons/cloud.svg';
      case 'minion':
        return 'lib/assets/icons/status_icons/minion.svg';
      case 'heart':
        return 'lib/assets/icons/status_icons/heart.svg';
      case 'star':
        return 'lib/assets/icons/status_icons/star.svg';
      case 'music':
        return 'lib/assets/icons/status_icons/music.svg';
      case 'location':
        return 'lib/assets/icons/status_icons/location.svg';
      case 'cake':
        return 'lib/assets/icons/status_icons/cake.svg';
      case 'chat':
        return 'lib/assets/icons/status_icons/chat.svg';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;

        // Проверка подписки для статуса (Premium, Ultimate, Max или Pick-me!)
        final hasRequiredSubscription = widget.subscription?.active == true &&
            (widget.subscription?.type.toLowerCase() == 'premium' ||
             widget.subscription?.type.toLowerCase() == 'ultimate' ||
             widget.subscription?.type.toLowerCase() == 'max' ||
             widget.subscription?.type.toLowerCase() == 'pick-me!');

        return Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статус',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Если есть подписка Premium/Ultimate/Pick-me!, показываем элементы управления
                if (hasRequiredSubscription) ...[
                  // Статус input с цветом фона и формой как у статуса
                  Builder(
                    builder: (context) {
                      final backgroundColor = _getBackgroundColor();
                      final textColor = _getTextColor(backgroundColor);
                      final selectedIconData = _getSelectedIconData();

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Иконка слева (если выбрана)
                              if (selectedIconData != null) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: SvgPicture.asset(
                                    selectedIconData,
                                    colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                                    width: 16,
                                    height: 16,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              // Текстовое поле с динамической шириной и переносом текста
                              IntrinsicWidth(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 120, // Минимальная ширина для пустого поля
                                    maxWidth: 300, // Максимальная ширина перед переносом
                                  ),
                                  child: TextField(
                                    controller: _displayController,
                                    maxLength: 50, // Ограничение на 50 символов
                                    maxLines: null, // Разрешить перенос текста на несколько строк
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.body.copyWith(color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'Что у вас на уме?',
                                      hintStyle: AppTextStyles.body.copyWith(
                                        color: textColor.withValues(alpha: 0.6),
                                      ),
                                      border: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      counterText: '', // Убираем встроенный счетчик
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Счетчик символов
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_displayController.text.length}/50',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Строка выбора иконок
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableIcons.map((iconName) {
                        final isSelected = _selectedIcon == iconName;
                        final iconPath = _getStatusIcon(iconName);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _selectIcon(iconName),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: SvgPicture.asset(
                                iconPath!,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Строка выбора цвета статуса
                  if (widget.onPickStatusColor != null)
                    InkWell(
                      onTap: widget.onPickStatusColor,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _getBackgroundColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Выбрать цвет статуса',
                                style: AppTextStyles.body,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  // Если нет подписки, показываем сообщение
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Доступно только для подписки',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Premium, Ultimate, Max или Pick-me!',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
