import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_text_styles.dart';

/// Кастомное контекстное меню для поля ввода поста с поддержкой markdown форматирования
class MarkdownContextMenu extends StatelessWidget {
  final BuildContext context;
  final EditableTextState editableTextState;

  const MarkdownContextMenu({
    super.key,
    required this.context,
    required this.editableTextState,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    final controller = editableTextState.widget.controller;
    final selection = controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      children.add(_buildMenuButton(
        label: 'Вырезать',
        onPressed: () async {
          final text = controller.text;
          final selectedText = text.substring(selection.start, selection.end);

          await Clipboard.setData(ClipboardData(text: selectedText));

          controller.text = text.replaceRange(selection.start, selection.end, '');
          controller.selection = TextSelection.collapsed(offset: selection.start);

          editableTextState.hideToolbar();
        },
        isDestructive: true,
      ));
    }

    if (selection.isValid && !selection.isCollapsed) {
      children.add(_buildMenuButton(
        label: 'Копировать',
        onPressed: () async {
          final text = controller.text;
          final selectedText = text.substring(selection.start, selection.end);

          await Clipboard.setData(ClipboardData(text: selectedText));

          editableTextState.hideToolbar();
        },
      ));
    }

    children.add(_buildMenuButton(
      label: 'Вставить',
      onPressed: () async {
        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
        if (clipboardData?.text?.isNotEmpty == true) {
          final text = controller.text;
          final cursorPosition = (selection.isValid ? selection.start : controller.selection.start)
              .clamp(0, text.length)
              .toInt();

          final newText = text.replaceRange(cursorPosition, cursorPosition, clipboardData!.text!);
          controller.text = newText;

          controller.selection = TextSelection.collapsed(
            offset: (cursorPosition + clipboardData.text!.length).clamp(0, newText.length),
          );
        }

        editableTextState.hideToolbar();
      },
      
    ));

    if (controller.text.isNotEmpty) {
      children.add(_buildMenuButton(
        label: 'Выделить все',
        onPressed: () {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );

        },
      ));
    }

    if (selection.isValid && !selection.isCollapsed) {

      children.addAll([
        _buildFormatButton('Жирный', '**', '**'),
        _buildFormatButton('Курсив', '*', '*'),
        _buildFormatButton('Зачеркнутый', '~~', '~~'),
        _buildFormatButton('Код', '`', '`'),
        _buildFormatButton('Ссылка', '[', '](url)'),
        _buildFormatButton('Заголовок', '# ', ''),
      ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AdaptiveTextSelectionToolbar(
        anchors: editableTextState.contextMenuAnchors,
        children: children,
      ),
    );
  }

  Widget _buildMenuButton({
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTextStyles.bodySecondary.copyWith(
          color: isDestructive
              ? Colors.red
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFormatButton(String label, String prefix, String suffix) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () => _applyFormatting(prefix, suffix),
      child: Text(
        label,
        style: AppTextStyles.bodySecondary.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  void _applyFormatting(String prefix, String suffix) {
    final controller = editableTextState.widget.controller;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) return;

    final text = controller.text;
    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);

    final isAlreadyFormatted = selectedText.startsWith(prefix) && selectedText.endsWith(suffix);

    String formattedText;
    int newStart;
    int newEnd;

    if (isAlreadyFormatted) {
      formattedText = selectedText.substring(prefix.length, selectedText.length - suffix.length);
      newStart = start;
      newEnd = start + formattedText.length;
    } else {
      formattedText = '$prefix$selectedText$suffix';
      newStart = start + prefix.length;
      newEnd = start + prefix.length + selectedText.length;
    }

    final newText = text.replaceRange(start, end, formattedText);
    controller.text = newText;

    controller.selection = TextSelection(
      baseOffset: newStart,
      extentOffset: newEnd,
    );

    editableTextState.hideToolbar();
  }
}
