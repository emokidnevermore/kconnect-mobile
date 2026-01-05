import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../profile/components/swipe_pop_container.dart';
import '../../../music/domain/models/track.dart';
import '../../../feed/presentation/blocs/feed_event.dart';
import '../../../feed/presentation/blocs/feed_bloc.dart';
import '../widgets/markdown_context_menu.dart';
import '../../../../shared/widgets/media_picker_modal.dart';
import '../blocs/post_creation_event.dart';
import '../../domain/models/post_creation_state.dart';
import '../blocs/post_creation_bloc.dart';

/// Экран создания поста
///
/// Предоставляет интерфейс для создания нового поста с текстом,
/// изображениями, видео и аудио. Поддерживает черновики и форматирование.
class PostCreationScreen extends StatefulWidget {
  const PostCreationScreen({super.key});

  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedText = '';
  final Map<String, Track> _selectedTracksMap = {};

  @override
  void initState() {
    super.initState();
    final state = context.read<PostCreationBloc>().state;
    _contentController.text = state.draftPost.content;
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    context.read<PostCreationBloc>().add(
      UpdateContentEvent(_contentController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostCreationBloc, PostCreationState>(
      listener: (context, state) {
        if (state.status == PostCreationStatus.success) {
          _navigateToFeedAndRefresh(context);
        } else if (state.status == PostCreationStatus.error && state.errorMessage != null) {
          _showErrorMessage(context, state.errorMessage!);
        }
      },
      child: BlocBuilder<PostCreationBloc, PostCreationState>(
        builder: (context, state) {
          return CupertinoPageScaffold(
            backgroundColor: AppColors.bgDark,
            navigationBar: CupertinoNavigationBar(
              backgroundColor: AppColors.bgDark.withValues(alpha: 0.8),
              middle: Text(
                'Новый пост',
                style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
              ),
              leading: CupertinoNavigationBarBackButton(
                color: context.dynamicPrimaryColor,
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: state.canPublish == true ? _publishPost : null,
                child: Icon(
                  CupertinoIcons.checkmark,
                  color: state.canPublish == true
                      ? context.dynamicPrimaryColor
                      : AppColors.textSecondary,
                  size: 24,
                ),
              ),
            ),
            child: SafeArea(
              child: SwipePopContainer(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 280,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedText.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.textSecondary.withValues(alpha: 0.1),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildInlineFormatButton('Жирный', '**', '**'),
                                        const SizedBox(width: 8),
                                        _buildInlineFormatButton('Курсив', '*', '*'),
                                        const SizedBox(width: 8),
                                        _buildInlineFormatButton('Зачеркнутый', '~~', '~~'),
                                        const SizedBox(width: 8),
                                        _buildInlineFormatButton('Код', '`', '`'),
                                      ],
                                    ),
                                  ),

                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CupertinoTextField(
                                    controller: _contentController,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: null,
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                      border: null,
                                    ),
                                    placeholder: 'Что у вас нового?',
                                    placeholderStyle: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    onChanged: (value) {
                                      setState(() {});
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        final selection = _contentController.selection;
                                        setState(() {
                                          _selectedText = selection.isValid && !selection.isCollapsed
                                              ? _contentController.text.substring(selection.start, selection.end)
                                              : '';
                                        });
                                      });
                                    },
                                    contextMenuBuilder: (context, editableTextState) {
                                      return MarkdownContextMenu(
                                        context: context,
                                        editableTextState: editableTextState,
                                      );
                                    },
                                  ),
                                ),

                                if (state.draftPost.imagePaths.isNotEmpty)
                                  _buildSelectedMediaList(state.draftPost.imagePaths),

                                if (state.draftPost.audioTrackIds.isNotEmpty)
                                  _buildSelectedTracksList(state.draftPost.audioTrackIds),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        border: Border(
                          top: BorderSide(
                            color: AppColors.textSecondary.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _showMediaPicker,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                CupertinoIcons.add,
                                color: context.dynamicPrimaryColor,
                                size: 20,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Text(
                            '${_contentController.text.length}',
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMediaPicker() {
    final postCreationBloc = context.read<PostCreationBloc>();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => MediaPickerModal(
        onMediaSelected: (imagePaths, tracks) {
          if (imagePaths.isNotEmpty) {
            postCreationBloc.add(AddImagesEvent(imagePaths));
          }

          if (tracks.isNotEmpty) {
            for (final track in tracks) {
              _selectedTracksMap[track.id.toString()] = track;
            }

            for (final track in tracks) {
              postCreationBloc.add(AddAudioTrackEvent(track.id.toString()));
            }
          }

        },
      ),
    );
  }

  Widget _buildInlineFormatButton(String label, String prefix, String suffix) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(32, 32),
      borderRadius: BorderRadius.circular(6),
      color: AppColors.bgDark.withValues(alpha: 0.3),
      onPressed: () => _applyInlineFormatting(prefix, suffix),
      child: Text(
        label,
        style: AppTextStyles.bodySecondary.copyWith(
          color: AppColors.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }

  void _applyInlineFormatting(String prefix, String suffix) {
    final selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _contentController.text;
    final selectedText = text.substring(selection.start, selection.end);

    final isAlreadyFormatted = selectedText.startsWith(prefix) && selectedText.endsWith(suffix);

    String formattedText;
    int newStart;
    int newEnd;

    if (isAlreadyFormatted) {
      formattedText = selectedText.substring(prefix.length, selectedText.length - suffix.length);
      newStart = selection.start;
      newEnd = selection.start + formattedText.length;
    } else {
      formattedText = '$prefix$selectedText$suffix';
      newStart = selection.start + prefix.length;
      newEnd = selection.start + prefix.length + selectedText.length;
    }

    final newText = text.replaceRange(selection.start, selection.end, formattedText);
    _contentController.text = newText;

    _contentController.selection = TextSelection(
      baseOffset: newStart,
      extentOffset: newEnd,
    );

    _onContentChanged();
  }

  Widget _buildSelectedMediaList(List<String> imagePaths) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Медиа (${imagePaths.length})',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length,
              itemBuilder: (context, index) {
                final imagePath = imagePaths[index];
                return _buildMediaPreviewItem(imagePath, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewItem(String imagePath, int index, [Key? key]) {
    return Container(
      key: key,
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.bgDark,
                    child: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: Colors.white,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeMediaItem(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          if (_isVideoFile(imagePath))
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  CupertinoIcons.video_camera,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isVideoFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension);
  }

  Widget _buildSelectedTracksList(List<String> trackIds) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Музыка (${trackIds.length})',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trackIds.length,
            itemBuilder: (context, index) {
              final trackId = trackIds[index];
              return _buildTrackItem(trackId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(String trackId) {
    final track = _selectedTracksMap[trackId];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppColors.bgDark,
            ),
            child: (track?.coverPath?.isNotEmpty == true)
                ? Builder(
                    builder: (context) {
                      final coverPath = track!.coverPath!;
                      final imageUrl = ImageUtils.getCompleteImageUrl(coverPath);
                      return imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  CupertinoIcons.music_note,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            )
                          : Icon(
                              CupertinoIcons.music_note,
                              color: AppColors.textSecondary,
                              size: 20,
                            );
                    },
                  )
                : Icon(
                    CupertinoIcons.music_note,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.title ?? 'Неизвестный трек',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track?.artist ?? 'Неизвестный исполнитель',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _removeTrack(trackId),
            child: Icon(
              CupertinoIcons.xmark_circle,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _removeMediaItem(int index) {
    final postCreationBloc = context.read<PostCreationBloc>();
    final currentState = postCreationBloc.state;

    final imagePath = currentState.draftPost.imagePaths[index];

    postCreationBloc.add(RemoveImageEvent(imagePath));
  }

  void _removeTrack(String trackId) {
    final postCreationBloc = context.read<PostCreationBloc>();
    postCreationBloc.add(RemoveAudioTrackEvent(trackId));
  }

  void _publishPost() {
    final selectedTracks = _selectedTracksMap.values.toList();
    context.read<PostCreationBloc>().add(PublishPostEvent(selectedTracks));
  }



  void _navigateToFeedAndRefresh(BuildContext context) {
    Navigator.of(context).pop();

    try {
      final feedBloc = context.read<FeedBloc>();
      feedBloc.add(const RefreshFeedEvent());
    } catch (e) {
      //Ошибка
    }
  }

  void _showErrorMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
