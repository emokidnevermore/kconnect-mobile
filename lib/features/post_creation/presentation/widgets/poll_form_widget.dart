import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../blocs/post_creation_event.dart';
import '../blocs/post_creation_bloc.dart';
import '../../domain/models/post_creation_state.dart';

/// Виджет формы опроса для создания поста
class PollFormWidget extends StatefulWidget {
  const PollFormWidget({super.key});

  @override
  State<PollFormWidget> createState() => _PollFormWidgetState();
}

class _PollFormWidgetState extends State<PollFormWidget> with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostCreationBloc, PostCreationState>(
      builder: (context, state) {
        if (!state.showPollForm) return const SizedBox.shrink();

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок опроса
                  Row(
                    children: [
                      Icon(
                        Icons.poll,
                        color: context.dynamicPrimaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Опрос',
                        style: AppTextStyles.h3.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          context.read<PostCreationBloc>().add(const TogglePollFormEvent());
                        },
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Поле вопроса
                  TextField(
                    controller: _questionController,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Вопрос опроса',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: context.dynamicPrimaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      counterText: '',
                    ),
                    onChanged: (value) {
                      context.read<PostCreationBloc>().add(UpdatePollQuestionEvent(value));
                    },
                  ),
                  const SizedBox(height: 16),

                  // Варианты ответов
                  Text(
                    'Варианты ответов',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._buildPollOptions(state),

                  // Кнопка добавления варианта
                  if (state.draftPost.pollOptions.length < 10)
                    TextButton.icon(
                      onPressed: _addPollOption,
                      icon: Icon(
                        Icons.add,
                        color: context.dynamicPrimaryColor,
                        size: 20,
                      ),
                      label: Text(
                        'Добавить вариант',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.dynamicPrimaryColor,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Настройки опроса
                  _buildPollSettings(state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPollOptions(PostCreationState state) {
    final options = <Widget>[];
    final pollOptions = state.draftPost.pollOptions;

    for (int i = 0; i < pollOptions.length; i++) {
      options.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _getOrCreateController(i, pollOptions[i]),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: 'Вариант ${i + 1}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.dynamicPrimaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    context.read<PostCreationBloc>().add(UpdatePollOptionEvent(i, value));
                  },
                ),
              ),
              if (pollOptions.length > 2)
                IconButton(
                  onPressed: () => _removePollOption(i),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  padding: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      );
    }

    return options;
  }

  Widget _buildPollSettings(PostCreationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Настройки',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Анонимность
        SwitchListTile(
          title: Text(
            'Анонимный опрос',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Результаты будут видны без имен участников',
            style: AppTextStyles.bodySecondary.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          value: state.draftPost.pollIsAnonymous,
          onChanged: (value) {
            context.read<PostCreationBloc>().add(TogglePollAnonymousEvent(value));
          },
          activeThumbColor: context.dynamicPrimaryColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),

        // Множественный выбор
        SwitchListTile(
          title: Text(
            'Множественный выбор',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Участники смогут выбрать несколько вариантов',
            style: AppTextStyles.bodySecondary.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          value: state.draftPost.pollIsMultiple,
          onChanged: (value) {
            context.read<PostCreationBloc>().add(TogglePollMultipleEvent(value));
          },
          activeThumbColor: context.dynamicPrimaryColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),

        // Срок окончания
        ListTile(
          title: Text(
            'Срок окончания',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            _getExpirationText(state.draftPost.pollExpiresInDays),
            style: AppTextStyles.bodySecondary.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          trailing: DropdownButton<int?>(
            value: state.draftPost.pollExpiresInDays,
            onChanged: (value) {
              context.read<PostCreationBloc>().add(UpdatePollExpiresInDaysEvent(value));
            },
            items: const [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('Без ограничений'),
              ),
              DropdownMenuItem<int?>(
                value: 1,
                child: Text('1 день'),
              ),
              DropdownMenuItem<int?>(
                value: 3,
                child: Text('3 дня'),
              ),
              DropdownMenuItem<int?>(
                value: 7,
                child: Text('7 дней'),
              ),
              DropdownMenuItem<int?>(
                value: 14,
                child: Text('14 дней'),
              ),
              DropdownMenuItem<int?>(
                value: 30,
                child: Text('30 дней'),
              ),
            ],
            underline: const SizedBox.shrink(),
          ),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  TextEditingController _getOrCreateController(int index, String initialValue) {
    while (_optionControllers.length <= index) {
      _optionControllers.add(TextEditingController());
    }

    final controller = _optionControllers[index];
    if (controller.text != initialValue) {
      controller.text = initialValue;
    }

    return controller;
  }

  void _addPollOption() {
    final bloc = context.read<PostCreationBloc>();
    final currentOptions = bloc.state.draftPost.pollOptions;
    final newOption = 'Вариант ${currentOptions.length + 1}';
    bloc.add(AddPollOptionEvent(newOption));
  }

  void _removePollOption(int index) {
    context.read<PostCreationBloc>().add(RemovePollOptionEvent(index));
  }

  String _getExpirationText(int? days) {
    if (days == null) return 'Без ограничений';
    if (days == 1) return '1 день';
    return '$days дней';
  }
}
