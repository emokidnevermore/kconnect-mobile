/// Диалог выбора цвета на основе Material Design 3
///
/// Предоставляет полноценный интерфейс для выбора цвета с несколькими вкладками:
/// - Material Colors: предустановленные цвета Material Design
/// - Custom Color: цветовой круг HSV с точной настройкой
/// - Recent Colors: последние выбранные цвета
library;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Диалог выбора цвета
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  final String? subtitle;
  final bool enableAlpha;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.title,
    this.subtitle,
    this.enableAlpha = false,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog>
    with TickerProviderStateMixin {
  late Color _selectedColor;
  late TabController _tabController;



  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle!,
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                 
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Готовые'),
                Tab(text: 'Свой'),
              ],
              labelStyle: AppTextStyles.bodySecondary.copyWith(
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: AppTextStyles.bodySecondary,
              indicatorSize: TabBarIndicatorSize.tab,
            ),

            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Отключаем свайп
                children: [
                  // Готовые цвета
                  _buildReadyColorsTab(),
                  // Custom Color Tab
                  _buildCustomColorTab(),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Отмена',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedColor),
                    child: Text(
                      'Выбрать',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyColorsTab() {
    // Список готовых цветов с их hex значениями
    final readyColors = [
      const Color(0xFFD0BCFF), // #D0BCFF
      const Color(0xFFFFFFFF), // #FFFFFF
      const Color(0xFF90CAF9), // #90CAF9
      const Color(0xFFA5D6A7), // #A5D6A7
      const Color(0xFFFFCC80), // #FFCC80
      const Color(0xFFEF9A9A), // #EF9A9A
      const Color(0xFFCE93D8), // #CE93D8
      const Color(0xFFFFF59D), // #FFF59D
      const Color(0xFFB0BEC5), // #B0BEC5
      const Color(0xFFF48FB1), // #F48FB1
      const Color(0xFF81D4FA), // #81D4FA
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Готовые цвета',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: readyColors.length,
            itemBuilder: (context, index) {
              final color = readyColors[index];
              final hexValue = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

              return ListTile(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == color
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      width: _selectedColor == color ? 3 : 1,
                    ),
                  ),
                ),
                title: Text(
                  hexValue,
                  style: AppTextStyles.body.copyWith(
                    fontFamily: 'monospace', // Моноширинный шрифт для hex значений
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: _selectedColor == color
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomColorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Пользовательский цвет',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {}, // Активируем взаимодействие
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.8, // Увеличили для лучшего доступа
              enableAlpha: widget.enableAlpha,
              displayThumbColor: true,
              showLabel: false,
              paletteType: PaletteType.hsvWithHue,
              pickerAreaBorderRadius: BorderRadius.circular(12),
              hexInputBar: true,
              hexInputController: TextEditingController(
                text: '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
              ),
            ),
          ),
        ],
      ),
    );
  }



}

/// Показать диалог выбора цвета
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initialColor,
  required String title,
  String? subtitle,
  bool enableAlpha = false,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => ColorPickerDialog(
      initialColor: initialColor,
      title: title,
      subtitle: subtitle,
      enableAlpha: enableAlpha,
    ),
  );
}
