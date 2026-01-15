import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../features/music/domain/models/track.dart';
import '../../features/music/presentation/blocs/music_bloc.dart';
import '../../features/music/presentation/blocs/music_event.dart';
import '../../features/music/presentation/blocs/music_state.dart';
import '../../features/music/widgets/track_list_item.dart';

/// Информация об альбоме для отображения в селекторе
class AlbumInfo {
  final AssetPathEntity album;
  final String name;
  final int assetCount;
  final AssetEntity? lastPhoto;
  Uint8List? lastPhotoPreview;

  AlbumInfo({
    required this.album,
    required this.name,
    required this.assetCount,
    this.lastPhoto,
    this.lastPhotoPreview,
  });

  /// Создание копии с обновленным превью
  AlbumInfo copyWithPreview(Uint8List preview) {
    return AlbumInfo(
      album: album,
      name: name,
      assetCount: assetCount,
      lastPhoto: lastPhoto,
      lastPhotoPreview: preview,
    );
  }
}

/// Единый пикер медиа контента с табами Фото/Музыка
/// Хранит состояние выбора и возвращает результат
class MediaPickerModal extends StatefulWidget {
  /// Callback для возврата выбранного контента
  /// imagePaths - список путей к изображениям
  /// videoPath - путь к видео (только одно видео)
  /// videoThumbnailPath - путь к превью видео
  /// tracks - список выбранных треков
  final Function(List<String> imagePaths, String? videoPath, String? videoThumbnailPath, List<Track> tracks)? onMediaSelected;

  /// Показывать только вкладку с фото (скрывать музыку)
  final bool photoOnly;

  /// Ограничить выбор одним объектом (1 фото или 1 видео)
  final bool singleSelection;

  const MediaPickerModal({
    super.key,
    this.onMediaSelected,
    this.photoOnly = false,
    this.singleSelection = false,
  });

  @override
  State<MediaPickerModal> createState() => _MediaPickerModalState();
}

class _MediaPickerModalState extends State<MediaPickerModal>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  final List<String> _selectedImagePaths = [];
  String? _selectedVideoPath;
  String? _selectedVideoThumbnailPath;
  final List<Track> _selectedTracks = [];

  List<AssetEntity> _galleryAssets = [];
  bool _loadingGallery = true;
  bool _hasGalleryPermission = false;

  // Кэш для путей к файлам для оптимизации производительности
  final Map<String, String> _assetPathCache = {};

  List<AssetPathEntity> _albums = [];
  List<AlbumInfo> _albumInfos = [];
  AssetPathEntity? _currentAlbum;
  String _currentAlbumName = 'Фото';
  int _currentPage = 1;
  bool _hasMorePages = true;
  bool _isLoadingMore = false;

  // Состояние музыки
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _photoScrollController = ScrollController();
  Timer? _debounceTimer;
  Timer? _paginationDebounceTimer;
  String _currentQuery = '';
  bool _musicLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.photoOnly ? 1 : 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _photoScrollController.addListener(_onPhotoScroll);
    if (!widget.photoOnly) {
      _tabController.addListener(_onTabChanged);
    }

    _loadGallery();

  }

  /// Обработчик бесконечной прокрутки для музыки
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final musicBloc = context.read<MusicBloc>();
      if (musicBloc.state.favoritesHasNextPage && musicBloc.state.favoritesStatus != MusicLoadStatus.loading) {
        debugPrint('🎵 MediaPicker: Loading more favorites');
        musicBloc.add(MusicFavoritesLoadMore());
      }
    }
  }

  /// Обработчик пагинации для фото
  void _onPhotoScroll() {
    if (_photoScrollController.position.pixels >= _photoScrollController.position.maxScrollExtent - 200) {
      if (_currentAlbum != null && _hasMorePages && !_isLoadingMore) {
        debugPrint('📱 MediaPicker: Loading more photos from "${_currentAlbum!.name}"');
        _loadMoreAlbumPhotos();
      }
    }
  }

  /// Загружает следующую страницу фото с debounce
  Future<void> _loadMoreAlbumPhotos() async {
    if (_isLoadingMore || !_hasMorePages || _currentAlbum == null) return;

    // Отменяем предыдущий таймер если он есть
    _paginationDebounceTimer?.cancel();

    // Устанавливаем debounce для setState
    _paginationDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return;

      setState(() => _isLoadingMore = true);

      try {
        final assets = await _currentAlbum!.getAssetListPaged(page: _currentPage, size: 50);

        // Фильтруем WebP
        final filteredAssets = assets.where((asset) {
          final fileName = asset.title?.toLowerCase() ?? '';
          return !fileName.endsWith('.webp');
        }).toList();

        // На iOS порядок уже правильный, не нужно делать reverse
        final orderedAssets = Platform.isIOS ? filteredAssets : filteredAssets.reversed.toList();

        if (mounted) {
          setState(() {
            _galleryAssets.addAll(orderedAssets);

            _currentPage--;

            _hasMorePages = _currentPage >= 0;
            _isLoadingMore = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _scrollController.removeListener(_onScroll);
    _photoScrollController.removeListener(_onPhotoScroll);
    _tabController.dispose();
    _scrollController.dispose();
    _photoScrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _paginationDebounceTimer?.cancel();
    _assetPathCache.clear();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_musicLoaded) {
      _musicLoaded = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MusicBloc>().add(MusicFavoritesFetched());
        }
      });
    }
    setState(() {});
  }

  Future<void> _loadGallery() async {
    setState(() => _loadingGallery = true);

    try {
      final ps = await PhotoManager.requestPermissionExtend();
      debugPrint('📱 MediaPicker: PermissionState = $ps, isAuth = ${ps.isAuth}');

      if (!ps.isAuth && ps != PermissionState.limited) {
        final retryPs = await PhotoManager.requestPermissionExtend();
        if (!retryPs.isAuth && retryPs != PermissionState.limited) {
          setState(() {
            _loadingGallery = false;
            _hasGalleryPermission = false;
          });
          return;
        }
      }

      _hasGalleryPermission = true;

      final imageAllAlbums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
      final videoAllAlbums = await PhotoManager.getAssetPathList(type: RequestType.video, hasAll: true);

      AssetPathEntity? imageAllAlbum;
      AssetPathEntity? videoAllAlbum;

      try {
        if (imageAllAlbums.isNotEmpty) {
          imageAllAlbum = imageAllAlbums.firstWhere((a) => a.isAll, orElse: () => imageAllAlbums.first);
        } else {
          final fallbackAlbums = await PhotoManager.getAssetPathList(type: RequestType.image);
          if (fallbackAlbums.isNotEmpty) {
            imageAllAlbum = fallbackAlbums.first;
          }
        }
      } catch (e) {
        //Ошибка
      }

      try {
        if (videoAllAlbums.isNotEmpty) {
          videoAllAlbum = videoAllAlbums.firstWhere((a) => a.isAll, orElse: () => videoAllAlbums.first);
        } else {
          final fallbackAlbums = await PhotoManager.getAssetPathList(type: RequestType.video);
          if (fallbackAlbums.isNotEmpty) {
            videoAllAlbum = fallbackAlbums.first;
          }
        }
      } catch (e) {
        //Ошибка
      }

      if (imageAllAlbum == null && videoAllAlbum == null) {
        setState(() => _loadingGallery = false);
        return;
      }

      final imageAlbums = await PhotoManager.getAssetPathList(type: RequestType.image);
      final videoAlbums = await PhotoManager.getAssetPathList(type: RequestType.video);

      _albums = <AssetPathEntity>{
        ...imageAlbums.where((a) => !a.isAll),
        ...videoAlbums.where((a) => !a.isAll)
      }.toList();

      final allAlbumInfos = await _createAlbumInfos(_albums);

      final virtualAlbumInfos = <AlbumInfo>[];

      AssetEntity? imagePreview;
      AssetEntity? videoPreview;

      if (imageAllAlbum != null) {
        try {
          final totalAssets = await imageAllAlbum.assetCountAsync;
          if (totalAssets > 0) {
            // На iOS порядок уже правильный (от новых к старым), берем первый элемент
            // На Android нужно брать последний
            final coverList = Platform.isIOS
                ? await imageAllAlbum.getAssetListRange(start: 0, end: 1)
                : await imageAllAlbum.getAssetListRange(
                    start: totalAssets - 1,
                    end: totalAssets,
                  );
            if (coverList.isNotEmpty) {
              imagePreview = coverList.first;
            }
          }
        } catch (e) {
          //Ошибка
        }

        virtualAlbumInfos.add(AlbumInfo(
          album: imageAllAlbum,
          name: 'Фото',
          assetCount: await imageAllAlbum.assetCountAsync,
          lastPhoto: imagePreview,
        ));
      }
    
      if (videoAllAlbum != null) {
        try {
          final totalAssets = await videoAllAlbum.assetCountAsync;
          if (totalAssets > 0) {
            // На iOS порядок уже правильный (от новых к старым), берем первый элемент
            // На Android нужно брать последний
            final coverList = Platform.isIOS
                ? await videoAllAlbum.getAssetListRange(start: 0, end: 1)
                : await videoAllAlbum.getAssetListRange(
                    start: totalAssets - 1,
                    end: totalAssets,
                  );
            if (coverList.isNotEmpty) {
              videoPreview = coverList.first;
            }
          }
        } catch (e) {
          //Ошибка
        }

        virtualAlbumInfos.add(AlbumInfo(
          album: videoAllAlbum,
          name: 'Видео',
          assetCount: await videoAllAlbum.assetCountAsync,
          lastPhoto: videoPreview,
        ));
      }
    
      final otherAlbumInfos = allAlbumInfos.where((info) =>
        info.album != imageAllAlbum && info.album != videoAllAlbum
      ).toList();
      otherAlbumInfos.sort((a, b) => b.assetCount.compareTo(a.assetCount));

      _albumInfos = [...virtualAlbumInfos, ...otherAlbumInfos];

      _currentAlbum = imageAllAlbum ?? _albums.first;
      _currentAlbumName = 'Фото';

      if (_currentAlbum != null) {
        await _loadAlbumPhotos(_currentAlbum!, reset: true);
      }

    } catch (e) {
      //Ошибка
    }

    setState(() => _loadingGallery = false);
  }



  /// Создает AlbumInfo для каждого альбома с превью последнего фото
  Future<List<AlbumInfo>> _createAlbumInfos(List<AssetPathEntity> albums) async {
    final albumInfos = <AlbumInfo>[];

    for (final album in albums) {
      try {
        final assetCount = await album.assetCountAsync;

        AssetEntity? lastPhoto;
        if (assetCount > 0) {
          // На iOS порядок уже правильный (от новых к старым), берем первый элемент
          // На Android нужно брать последний
          final coverList = Platform.isIOS
              ? await album.getAssetListRange(start: 0, end: 1)
              : await album.getAssetListRange(
                  start: assetCount - 1,
                  end: assetCount,
                );
          if (coverList.isNotEmpty) {
            lastPhoto = coverList.first;
          }
        }

        albumInfos.add(AlbumInfo(
          album: album,
          name: album.name,
          assetCount: assetCount,
          lastPhoto: lastPhoto,
        ));
      } catch (e) {
        albumInfos.add(AlbumInfo(
          album: album,
          name: album.name,
          assetCount: 0,
        ));
      }
    }

    albumInfos.sort((a, b) => b.assetCount.compareTo(a.assetCount));

    return albumInfos;
  }

  /// Загружает фото из выбранного альбома (от свежих к старым)
  Future<void> _loadAlbumPhotos(AssetPathEntity album, {bool reset = false}) async {
    if (reset) {
      final totalAssets = await album.assetCountAsync;
      final totalPages = (totalAssets / 50).ceil();
      _currentPage = totalPages - 1;
      _hasMorePages = true;
      _galleryAssets = [];
    }

    if (!_hasMorePages || _currentPage < 0) return;

    try {
      final assets = await album.getAssetListPaged(page: _currentPage, size: 50);

      final filteredAssets = assets.where((asset) {
        final fileName = asset.title?.toLowerCase() ?? '';
        return !fileName.endsWith('.webp');
      }).toList();

      // На iOS порядок уже правильный, не нужно делать reverse
      final orderedAssets = Platform.isIOS ? filteredAssets : filteredAssets.reversed.toList();

      if (reset) {
        _galleryAssets = orderedAssets;
      } else {
        _galleryAssets.addAll(orderedAssets);
      }

      _currentPage--;

      _hasMorePages = _currentPage >= 0 || orderedAssets.length == 50;

      if (reset && album.isAll && orderedAssets.length < 25 && _hasMorePages) {
        await _loadMoreAlbumPhotos();
      }

    } catch (e) {
      //Ошибка
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() => _currentQuery = '');
      context.read<MusicBloc>().add(MusicTracksSearched(''));
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (query.length >= 2 && query != _currentQuery) {
        setState(() => _currentQuery = query);
        context.read<MusicBloc>().add(MusicTracksSearched(query));
      }
    });
  }

  void _toggleImageSelection(AssetEntity asset) async {
    final isVideo = asset.type == AssetType.video;

    // В режиме singleSelection автоматически снимаем предыдущий выбор
    if (widget.singleSelection) {
      if (isVideo && _selectedImagePaths.isNotEmpty) {
        _selectedImagePaths.clear();
      }
      if (!isVideo && _selectedVideoPath != null) {
        _selectedVideoPath = null;
        _selectedVideoThumbnailPath = null;
      }
      // Если выбран другой объект того же типа, снимаем его
      if (isVideo && _selectedVideoPath != null) {
        _selectedVideoPath = null;
        _selectedVideoThumbnailPath = null;
      }
      if (!isVideo && _selectedImagePaths.isNotEmpty) {
        _selectedImagePaths.clear();
      }
    } else {

    }

    final file = await asset.file;
    if (file == null) return;

    final path = file.path;

    // Валидация: только одно видео (если уже выбрано другое видео, заменяем его)
    if (isVideo && _selectedVideoPath != null && _selectedVideoPath != path) {
      // Заменяем старое видео на новое
      _selectedVideoPath = null;
      _selectedVideoThumbnailPath = null;
    }

    if (isVideo) {
      // Обработка видео
      setState(() {
        if (_selectedVideoPath == path) {
          // Удаляем видео
          _selectedVideoPath = null;
          _selectedVideoThumbnailPath = null;
        } else {
          // Выбираем видео и генерируем thumbnail
          _selectedVideoPath = path;
          _generateVideoThumbnail(asset);
        }
      });
    } else {
      // Обработка изображений
      setState(() {
        if (_selectedImagePaths.contains(path)) {
          _selectedImagePaths.remove(path);
        } else {
          _selectedImagePaths.add(path);
        }
      });
    }
  }

  /// Генерирует и сохраняет thumbnail для видео
  Future<void> _generateVideoThumbnail(AssetEntity asset) async {
    try {
      final thumbnailBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(400),
      );

      if (thumbnailBytes != null && mounted) {
        // Сохраняем thumbnail во временный файл
        final tempDir = Directory.systemTemp;
        final thumbnailFile = File('${tempDir.path}/video_thumbnail_${asset.id}.jpg');
        await thumbnailFile.writeAsBytes(thumbnailBytes);

        setState(() {
          _selectedVideoThumbnailPath = thumbnailFile.path;
        });
      }
    } catch (e) {
      debugPrint('Ошибка генерации thumbnail для видео: $e');
      // Продолжаем без thumbnail
    }
  }



  void _toggleTrackSelection(Track track) {
    setState(() {
      if (_selectedTracks.contains(track)) {
        _selectedTracks.remove(track);
      } else {
        if (_selectedTracks.length < 3) {
          _selectedTracks.add(track);
        }
      }
    });
  }

  void _confirmSelection() {
    widget.onMediaSelected?.call(
      _selectedImagePaths,
      _selectedVideoPath,
      _selectedVideoThumbnailPath,
      _selectedTracks,
    );
    Navigator.of(context).pop();
  }

  /// Создает динамическую кнопку вкладки фото
  Tab _buildPhotoTabLabel() {
    if (_tabController.index == 0) {
      return Tab(
        child: GestureDetector(
          onTap: _showAlbumSelector,
          behavior: HitTestBehavior.opaque,
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo, size: 16),
                const SizedBox(width: 4),
                Text(_currentAlbumName),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more, size: 12),
              ],
            ),
          ),
        ),
      );
    } else {
      return Tab(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo, size: 16),
              const SizedBox(width: 4),
              const Text('Фото'),
            ],
          ),
        ),
      );
    }
  }

  /// Создает кнопку вкладки музыки
  Tab _buildMusicTabLabel() {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 16),
            const SizedBox(width: 4),
            const Text('Музыка'),
          ],
        ),
      ),
    );
  }



  /// Показывает bottom sheet с выбором альбомов
  void _showAlbumSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text('Выберите альбом', style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Закрыть', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _albumInfos.length,
                itemBuilder: (context, index) {
                  final albumInfo = _albumInfos[index];
                  final album = albumInfo.album;
                  final isSelected = album == _currentAlbum;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _switchToAlbum(album);
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                          // Превью последнего фото или иконка
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected ? Border.all(color: context.dynamicPrimaryColor, width: 2) : null,
                            ),
                            child: albumInfo.lastPhotoPreview != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      albumInfo.lastPhotoPreview!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(Icons.photo, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                : albumInfo.lastPhoto != null
                                    ? FutureBuilder<Uint8List?>(
                                        future: albumInfo.lastPhoto!.thumbnailDataWithSize(const ThumbnailSize.square(80)),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData && snapshot.data != null) {
                                            // Сохраняем превью в кэш для будущих использований
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              if (mounted) {
                                                setState(() {
                                                  _albumInfos[index] = albumInfo.copyWithPreview(snapshot.data!);
                                                });
                                              }
                                            });

                                            return ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.memory(
                                                snapshot.data!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Icon(Icons.photo, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                              ),
                                            );
                                          } else {
                                            return Icon(Icons.photo, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant);
                                          }
                                        },
                                      )
                                    : Icon(Icons.photo, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),

                          // Название и количество фото
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  albumInfo.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // Количество фото
                                Text(
                                  '${albumInfo.assetCount}',
                                  style: AppTextStyles.bodySecondary.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),

                            // Индикатор выбора
                            if (isSelected)
                              Icon(Icons.check, color: context.dynamicPrimaryColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Переключается на выбранный альбом
  void _switchToAlbum(AssetPathEntity album) {
    if (album == _currentAlbum) return;

    String albumName;
    if (album.isAll) {
      final imageAllAlbum = _albumInfos.firstWhere(
        (info) => info.album.isAll && info.name == 'Фото',
        orElse: () => _albumInfos.first,
      ).album;

      albumName = album == imageAllAlbum ? 'Фото' : 'Видео';
    } else {
      albumName = album.name;
    }

    setState(() {
      _currentAlbum = album;
      _currentAlbumName = albumName;
      _loadingGallery = true;
    });

    _loadAlbumPhotos(album, reset: true).then((_) {
      setState(() => _loadingGallery = false);
    });
  }

  bool get _hasContent => _selectedImagePaths.isNotEmpty || _selectedVideoPath != null || _selectedTracks.isNotEmpty;
  int get _totalSelected => _selectedImagePaths.length + (_selectedVideoPath != null ? 1 : 0) + _selectedTracks.length;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Заголовок с кнопками
          _buildHeader(),

          // TabBar с динамическими кнопками (скрыт если photoOnly)
          if (!widget.photoOnly)
            Material(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                tabs: [
                  _buildPhotoTabLabel(),
                  _buildMusicTabLabel(),
                ],
                labelColor: context.dynamicPrimaryColor,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: context.dynamicPrimaryColor,
                labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppTextStyles.bodyMedium,
              ),
            ),

          // Содержимое табов
          Expanded(
            child: widget.photoOnly
                ? _buildPhotoTab()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPhotoTab(),
                      _buildMusicTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Закрыть', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const Spacer(),
          // В режиме photoOnly показываем выбор альбома
          widget.photoOnly
              ? TextButton(
                  onPressed: _showAlbumSelector,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentAlbumName,
                        style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          const Spacer(),
          TextButton(
            onPressed: _hasContent ? _confirmSelection : null,
            child: Text(
              _hasContent ? 'Готово ($_totalSelected)' : 'Готово',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _hasContent ? context.dynamicPrimaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTab() {
    if (_loadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasGalleryPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Нет доступа к галерее', style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text('Предоставьте разрешение для доступа к фото', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _loadGallery,
                child: Text('Попробовать снова', style: AppTextStyles.bodyMedium.copyWith(color: context.dynamicPrimaryColor)),
              ),
            ],
          ),
        ),
      );
    }

    if (_galleryAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Галерея пуста', style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _photoScrollController,
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: _galleryAssets.length + (_hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        // Индикатор загрузки
        if (index == _galleryAssets.length) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final asset = _galleryAssets[index];
        return RepaintBoundary(
          child: FutureBuilder<String?>(
            future: _getAssetPath(asset),
            builder: (context, snapshot) {
              final path = snapshot.data;
              final isSelected = path != null && _selectedImagePaths.contains(path);

              return GestureDetector(
                onTap: () => _toggleImageSelection(asset),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image(
                        image: AssetEntityImageProvider(
                          asset,
                          isOriginal: false,
                          // Оптимизация размера thumbnail для iOS
                          thumbnailSize: Platform.isIOS
                              ? const ThumbnailSize.square(150)
                              : const ThumbnailSize.square(200),
                        ),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Center(
                              child: Icon(
                                Icons.warning,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 4, right: 4,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: context.dynamicPrimaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      ),
                    if (asset.type == AssetType.video)
                      Positioned(
                        bottom: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.videocam, size: 12, color: Colors.white),
                        ),
                      ),
                  if (!isSelected && _selectedImagePaths.length >= 10 && asset.type != AssetType.video)
                    Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3))),
                  if (!isSelected && asset.type == AssetType.video && _selectedVideoPath != null && path != _selectedVideoPath)
                    Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3))),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _getAssetPath(AssetEntity asset) async {
    // Проверяем кэш
    if (_assetPathCache.containsKey(asset.id)) {
      return _assetPathCache[asset.id];
    }

    try {
      final file = await asset.file;
      final path = file?.path;
      if (path != null) {
        _assetPathCache[asset.id] = path;
      }
      return path;
    } catch (e) {
      return null;
    }
  }

  Widget _buildMusicTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.transparent,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Введите название трека, артиста...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<MusicBloc, MusicState>(
            builder: (context, state) {
              if (_currentQuery.isEmpty) {
                return _buildFavoritesSection(state);
              } else {
                return _buildSearchResults(state);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesSection(MusicState state) {
    if (state.favoritesStatus == MusicLoadStatus.loading && state.favorites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.favoritesStatus == MusicLoadStatus.failure && state.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Ошибка загрузки', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<MusicBloc>().add(MusicFavoritesFetched()),
              child: Text('Повторить', style: AppTextStyles.bodyMedium.copyWith(color: context.dynamicPrimaryColor)),
            ),
          ],
        ),
      );
    }

    if (state.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('У вас пока нет любимых треков', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Добавьте треки в избранное в разделе музыки', style: AppTextStyles.bodySecondary.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<MusicBloc>().add(MusicFavoritesFetched(forceRefresh: true)),
      color: context.dynamicPrimaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 80),
        itemCount: state.favorites.length + (state.favoritesHasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.favorites.length) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
          }

          final track = state.favorites[index];
          final isSelected = _selectedTracks.contains(track);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? context.dynamicPrimaryColor.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: context.dynamicPrimaryColor.withValues(alpha: 0.3), width: 1) : null,
            ),
            child: Stack(
              children: [
                TrackListItem(
                  track: track,
                  onTap: () => _toggleTrackSelection(track),
                  showLikeButton: false,
                ),
                if (!isSelected && _selectedTracks.length >= 3)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(MusicState state) {
    if (state.searchStatus == MusicLoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.searchStatus == MusicLoadStatus.failure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Ошибка поиска', style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            Text('Попробуйте ещё раз', style: AppTextStyles.bodySecondary),
          ],
        ),
      );
    }

    if (state.searchResults.isEmpty && _currentQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Ничего не найдено', style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Попробуйте изменить запрос', style: AppTextStyles.bodySecondary),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 80),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final track = state.searchResults[index];
        final isSelected = _selectedTracks.contains(track);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.dynamicPrimaryColor.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: context.dynamicPrimaryColor.withValues(alpha: 0.3), width: 1) : null,
          ),
          child: Stack(
            children: [
              TrackListItem(
                track: track,
                onTap: () => _toggleTrackSelection(track),
                showLikeButton: false,
              ),
              if (!isSelected && _selectedTracks.length >= 3)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
