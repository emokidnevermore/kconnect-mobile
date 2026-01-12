import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/authorized_cached_network_image.dart';
import '../../../profile/components/swipe_pop_container.dart';
import '../../../music/domain/models/track.dart';
import '../../../feed/presentation/blocs/feed_event.dart';
import '../../../feed/presentation/blocs/feed_bloc.dart';
import '../widgets/markdown_context_menu.dart';
import '../widgets/poll_form_widget.dart';
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

  /// Флаг предотвращения множественных нажатий на кнопку публикации
  bool _isPublishButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // Сбрасываем состояние при входе в экран
    context.read<PostCreationBloc>().add(const ResetStateEvent());

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
          // Сбрасываем состояние BLoC для следующего использования
          context.read<PostCreationBloc>().add(const ResetStateEvent());
          // Сбрасываем флаг кнопки перед навигацией
          setState(() {
            _isPublishButtonPressed = false;
          });
          _navigateToFeedAndRefresh(context);
        } else if (state.status == PostCreationStatus.error && state.errorMessage != null) {
          // Сбрасываем флаг кнопки при ошибке
          setState(() {
            _isPublishButtonPressed = false;
          });
          _showErrorMessage(context, state.errorMessage!);
        }
      },
      child: BlocBuilder<PostCreationBloc, PostCreationState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Новый пост',
                style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              leading: BackButton(
                color: context.dynamicPrimaryColor,
              ),
              actions: [
                IconButton(
                  onPressed: state.canPublish == true ? _publishPost : null,
                  icon: Icon(
                    Icons.check,
                    color: state.canPublish == true
                        ? context.dynamicPrimaryColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ],
            ),
            body: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
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
                          child: Card(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
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
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
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
                                  child: TextField(
                                    controller: _contentController,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: null,
                                    decoration: InputDecoration(
                                      hintText: 'Что у вас нового?',
                                      border: InputBorder.none,
                                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      contentPadding: EdgeInsets.zero,
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

                                if (state.draftPost.videoPath != null)
                                  _buildSelectedVideo(state.draftPost.videoPath!, state.draftPost.videoThumbnailPath),

                                if (state.draftPost.audioTrackIds.isNotEmpty)
                                  _buildSelectedTracksList(state.draftPost.audioTrackIds),

                                // Poll form
                                const PollFormWidget(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _showMediaPicker,
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.add,
                                color: context.dynamicPrimaryColor,
                                size: 20,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          IconButton(
                            onPressed: _togglePollForm,
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: state.showPollForm
                                    ? context.dynamicPrimaryColor.withValues(alpha: 0.2)
                                    : context.dynamicPrimaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.poll,
                                color: state.showPollForm
                                    ? context.dynamicPrimaryColor
                                    : context.dynamicPrimaryColor.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Text(
                            '${_contentController.text.length}',
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
        onMediaSelected: (imagePaths, videoPath, videoThumbnailPath, tracks) {
          // Обработка изображений
          if (imagePaths.isNotEmpty) {
            postCreationBloc.add(AddImagesEvent(imagePaths));
          }

          // Обработка видео
          if (videoPath != null) {
            postCreationBloc.add(AddVideoEvent(videoPath, videoThumbnailPath: videoThumbnailPath));
          }

          // Обработка музыки
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
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(32, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
      ),
      onPressed: () => _applyInlineFormatting(prefix, suffix),
      child: Text(
        label,
        style: AppTextStyles.bodySecondary.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
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
              color: Theme.of(context).colorScheme.onSurface,
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
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
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
                    color: Theme.of(context).colorScheme.surface,
                    child: const Icon(
                      Icons.warning,
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
                  Icons.close,
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
                  Icons.videocam,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
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
              color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
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
              color: Theme.of(context).colorScheme.surface,
            ),
            child: (track?.coverPath?.isNotEmpty == true)
                ? Builder(
                    builder: (context) {
                      final coverPath = track!.coverPath!;
                      final imageUrl = ImageUtils.getCompleteImageUrl(coverPath);
                      return imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: AuthorizedCachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                errorWidget: (context, url, error) => Icon(
                                  Icons.music_note,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 20,
                            );
                    },
                  )
                : Icon(
                    Icons.music_note,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track?.artist ?? 'Неизвестный исполнитель',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _removeTrack(trackId),
            icon: Icon(
              Icons.cancel,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildSelectedVideo(String videoPath, String? thumbnailPath) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Видео',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: thumbnailPath != null
                        ? Image.file(
                            File(thumbnailPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Center(
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                ),
                // Кнопка play
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                // Кнопка удаления
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      context.read<PostCreationBloc>().add(const RemoveVideoEvent());
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _removeTrack(String trackId) {
    final postCreationBloc = context.read<PostCreationBloc>();
    postCreationBloc.add(RemoveAudioTrackEvent(trackId));
  }

  void _togglePollForm() {
    context.read<PostCreationBloc>().add(const TogglePollFormEvent());
  }

  void _publishPost() {

    // Предотвращаем множественные нажатия
    if (_isPublishButtonPressed) {
      return;
    }

    setState(() {
      _isPublishButtonPressed = true;
    });

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
