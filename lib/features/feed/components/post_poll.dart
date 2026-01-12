/// Компонент для отображения опросов в постах
///
/// Отображает опрос с вопросом, вариантами ответов, прогресс-барами и процентами.
/// Поддерживает голосование с анимациями и обновлением в реальном времени.
/// Использует Material Design 3 стилизацию.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/widgets/profile_accent_color_provider.dart';
import '../../../services/storage_service.dart';
import '../../../features/feed/domain/models/poll.dart';
import '../../../features/feed/domain/models/poll_option.dart';
import '../presentation/blocs/feed_bloc.dart';
import '../presentation/blocs/feed_event.dart';

/// Виджет опроса для поста
class PostPoll extends StatefulWidget {
  /// Опрос для отображения
  final Poll poll;

  /// ID поста, содержащего опрос
  final int postId;

  /// Флаг прозрачного фона
  final bool transparentBackground;

  /// Флаг полупрозрачного фона
  final bool semiTransparent;

  /// Цвет фона
  final Color? backgroundColor;

  /// Прозрачность
  final double? opacity;

  /// Флаг наличия фонового изображения профиля
  final bool? hasProfileBackground;

  /// Локальная ColorScheme профиля
  final ColorScheme? profileColorScheme;

  /// Коллбек для голосования (для использования в профиле)
  final Function()? onVote;

  /// Коллбек для оптимистичного обновления состояния опроса
  final Function(Poll updatedPoll)? onPollUpdate;

  const PostPoll({
    super.key,
    required this.poll,
    required this.postId,
    this.transparentBackground = false,
    this.semiTransparent = false,
    this.backgroundColor,
    this.opacity,
    this.hasProfileBackground,
    this.profileColorScheme,
    this.onVote,
    this.onPollUpdate,
  });

  @override
  State<PostPoll> createState() => _PostPollState();
}

class _PostPollState extends State<PostPoll> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late List<AnimationController> _optionControllers;
  late List<Animation<double>> _progressAnimations;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _hasVoted = widget.poll.userVoted;
    
    // Анимация появления опроса
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Анимации для каждого варианта ответа
    _optionControllers = List.generate(
      widget.poll.options.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );
    
    _progressAnimations = _optionControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ),
      );
    }).toList();
    
    // Запускаем анимацию появления
    _fadeController.forward();
    
    // Если уже проголосовано, показываем результаты сразу
    if (_hasVoted) {
      for (var controller in _optionControllers) {
        controller.value = 1.0;
      }
    }
  }

  @override
  void didUpdateWidget(PostPoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Если опрос обновился (после голосования), анимируем прогресс-бары
    if (widget.poll.userVoted && !oldWidget.poll.userVoted) {
      _hasVoted = true;
      for (var controller in _optionControllers) {
        controller.forward(from: 0.0);
      }
    } else if (widget.poll.userVoted) {
      // Обновляем анимации при изменении процентов
      for (int i = 0; i < _optionControllers.length; i++) {
        _optionControllers[i].animateTo(
          widget.poll.options[i].percentage / 100.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleVote(int optionId) {
    if (widget.poll.isExpired) return;

    HapticFeedback.lightImpact();

    List<int> optionIds;
    if (widget.poll.isMultipleChoice) {
      // Для множественного выбора: добавляем/убираем вариант из текущего списка
      if (widget.poll.userVoteOptionIds.contains(optionId)) {
        optionIds = widget.poll.userVoteOptionIds.where((id) => id != optionId).toList();
      } else {
        optionIds = [...widget.poll.userVoteOptionIds, optionId];
      }
    } else {
      // Для одиночного выбора: если пользователь повторно нажал на выбранный вариант, отменяем голос
      if (widget.poll.userVoteOptionIds.contains(optionId)) {
        optionIds = []; // Пустой список для отмены голоса
      } else {
        optionIds = [optionId];
      }
    }

    // Оптимистичное обновление состояния опроса для лучшего UX
    if (widget.onPollUpdate != null) {
      final updatedPoll = widget.poll.copyWith(
        userVoteOptionIds: optionIds,
        userVoted: optionIds.isNotEmpty,
      );
      widget.onPollUpdate!(updatedPoll);
    }

    // Используем коллбек, если он предоставлен (например, в профиле)
    if (widget.onVote != null) {
      widget.onVote!();
    } else {
      // По умолчанию используем FeedBloc
      context.read<FeedBloc>().add(
        VotePollEvent(widget.postId, widget.poll.id, optionIds, isMultipleChoice: widget.poll.isMultipleChoice, hasExistingVotes: widget.poll.userVoted),
      );
    }
  }

  String _formatExpiresAt(String? expiresAt) {
    if (expiresAt == null) return '';
    try {
      final dateTime = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = dateTime.difference(now);
      
      if (difference.isNegative) return 'Истек';
      
      if (difference.inDays > 0) {
        return 'Осталось ${difference.inDays} дн.';
      } else if (difference.inHours > 0) {
        return 'Осталось ${difference.inHours} ч.';
      } else if (difference.inMinutes > 0) {
        return 'Осталось ${difference.inMinutes} мин.';
      } else {
        return 'Скоро истечет';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = context.profileAccentColor;
    
    // Используем ту же логику цвета, что и для карточки поста
    final hasBackground = widget.hasProfileBackground ?? 
        (StorageService.appBackgroundPathNotifier.value != null && StorageService.appBackgroundPathNotifier.value!.isNotEmpty);
    final cardColor = widget.transparentBackground
        ? (hasBackground 
            ? colorScheme.surface.withValues(alpha: 0.7)
            : (widget.profileColorScheme?.surfaceContainerLow ?? colorScheme.surfaceContainerLow))
        : (widget.semiTransparent
            ? colorScheme.surface.withValues(alpha: 0.5)
            : (widget.backgroundColor?.withValues(alpha: widget.opacity ?? 1) ?? colorScheme.surfaceContainer.withValues(alpha: widget.opacity ?? 1.0)));
    
    return FadeTransition(
      opacity: _fadeController,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        color: cardColor,
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Индикатор типа опроса
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ПУБЛИЧНЫЙ ОПРОС',
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Вопрос опроса
              Text(
                widget.poll.question,
                style: AppTextStyles.h3.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Варианты ответа
              ...widget.poll.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = widget.poll.userVoteOptionIds.contains(option.id);
                
                return _PollOptionWidget(
                  key: ValueKey(option.id),
                  option: option,
                  isSelected: isSelected,
                  showResults: widget.poll.userVoted || widget.poll.isExpired,
                  totalVotes: widget.poll.totalVotes,
                  progressAnimation: _progressAnimations[index],
                  onTap: widget.poll.isExpired
                      ? null
                      : () => _handleVote(option.id),
                  colorScheme: colorScheme,
                  accentColor: accentColor,
                  transparentBackground: widget.transparentBackground,
                  semiTransparent: widget.semiTransparent,
                  hasProfileBackground: widget.hasProfileBackground,
                  profileColorScheme: widget.profileColorScheme,
                );
              }),
              
              // Общее количество голосов и время истечения
              if (widget.poll.totalVotes > 0 || (widget.poll.expiresAt != null && !widget.poll.isExpired)) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Количество голосов слева
                    if (widget.poll.totalVotes > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.how_to_vote,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.poll.totalVotes} ${_getVotesText(widget.poll.totalVotes)}',
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    // Время истечения справа
                    if (widget.poll.expiresAt != null && !widget.poll.isExpired)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatExpiresAt(widget.poll.expiresAt),
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getVotesText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'голос';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'голоса';
    } else {
      return 'голосов';
    }
  }
}

/// Виджет варианта ответа в опросе
class _PollOptionWidget extends StatefulWidget {
  final PollOption option;
  final bool isSelected;
  final bool showResults;
  final int totalVotes;
  final Animation<double> progressAnimation;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  final Color accentColor;
  final bool transparentBackground;
  final bool semiTransparent;
  final bool? hasProfileBackground;
  final ColorScheme? profileColorScheme;

  const _PollOptionWidget({
    super.key,
    required this.option,
    required this.isSelected,
    required this.showResults,
    required this.totalVotes,
    required this.progressAnimation,
    this.onTap,
    required this.colorScheme,
    required this.accentColor,
    required this.transparentBackground,
    required this.semiTransparent,
    this.hasProfileBackground,
    this.profileColorScheme,
  });

  @override
  State<_PollOptionWidget> createState() => _PollOptionWidgetState();
}

class _PollOptionWidgetState extends State<_PollOptionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    if (widget.isSelected) {
      _scaleController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_PollOptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.showResults ? widget.option.percentage : 0.0;
    final hasVotes = widget.totalVotes > 0;

    // Используем ту же логику цвета, что и для других карточек в приложении
    final hasBackground = widget.hasProfileBackground ??
        (StorageService.appBackgroundPathNotifier.value != null && StorageService.appBackgroundPathNotifier.value!.isNotEmpty);
    final backgroundColor = widget.transparentBackground
        ? (hasBackground
            ? widget.colorScheme.surface.withValues(alpha: 0.7)
            : (widget.profileColorScheme?.surfaceContainerLow ?? widget.colorScheme.surfaceContainerLow))
        : (widget.semiTransparent
            ? widget.colorScheme.surface.withValues(alpha: 0.5)
            : widget.colorScheme.surfaceContainer);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isSelected && widget.showResults
                  ? widget.accentColor.withValues(alpha: 0.15)
                  : backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected && widget.showResults
                    ? widget.accentColor
                    : widget.colorScheme.outline.withValues(alpha: 0.2),
                width: widget.isSelected && widget.showResults ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.option.text,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: widget.colorScheme.onSurface,
                            fontWeight: widget.isSelected && widget.showResults
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (widget.showResults && hasVotes)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: widget.isSelected
                                  ? widget.accentColor
                                  : widget.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.showResults && hasVotes) ...[
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: widget.progressAnimation,
                      builder: (context, child) {
                        final animatedPercentage = percentage * widget.progressAnimation.value;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: animatedPercentage / 100.0,
                            minHeight: 6,
                            backgroundColor: widget.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isSelected
                                  ? widget.accentColor
                                  : widget.colorScheme.primaryContainer,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (widget.showResults && hasVotes && widget.option.votesCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${widget.option.votesCount} ${_getVotesText(widget.option.votesCount)}',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: widget.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  String _getVotesText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'голос';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'голоса';
    } else {
      return 'голосов';
    }
  }
}
