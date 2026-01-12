import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Виджет разделителя даты для списка сообщений
///
/// Отображает дату между сообщениями разных дней
class DateDivider extends StatelessWidget {
  final DateTime date;

  const DateDivider({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Сегодня';
    } else if (messageDate == yesterday) {
      dateText = 'Вчера';
    } else {
      // Format date as "dd MMMM yyyy" (e.g., "15 января 2024")
      dateText = DateFormat('d MMMM yyyy', 'ru').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dateText,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
