import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_colors.dart';
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
  final Function(List<String> imagePaths, List<Track> tracks)? onMediaSelected;

  const MediaPickerModal({
    super.key,
    this.onMediaSelected,
  });

  @override
  State<MediaPickerModal> createState() => _MediaPickerModalState();
}

class _MediaPickerModalState extends State<MediaPickerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _selectedImagePaths = [];
  final List<Track> _selectedTracks = [];

  List<AssetEntity> _galleryAssets = [];
  bool _loadingGallery = true;
  bool _hasGalleryPermission = false;

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
  String _currentQuery = '';
  bool _musicLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _photoScrollController.addListener(_onPhotoScroll);
    _tabController.addListener(_onTabChanged);

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

  /// Загружает следующую страницу фото
  Future<void> _loadMoreAlbumPhotos() async {
    if (_isLoadingMore || !_hasMorePages || _currentAlbum == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final assets = await _currentAlbum!.getAssetListPaged(page: _currentPage, size: 50);

      // Фильтруем WebP
      final filteredAssets = assets.where((asset) {
        final fileName = asset.title?.toLowerCase() ?? '';
        return !fileName.endsWith('.webp');
      }).toList();

      setState(() {
        _galleryAssets.addAll(filteredAssets);

        _currentPage--;

        _hasMorePages = _currentPage >= 0;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
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
            final coverList = await imageAllAlbum.getAssetListRange(
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
            final coverList = await videoAllAlbum.getAssetListRange(
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
          final coverList = await album.getAssetListRange(
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
      }).toList().reversed.toList();

      if (reset) {
        _galleryAssets = filteredAssets;
      } else {
        _galleryAssets.addAll(filteredAssets);
      }

      _currentPage--;

      _hasMorePages = _currentPage >= 0 || filteredAssets.length == 50;

      if (reset && album.isAll && filteredAssets.length < 25 && _hasMorePages) {
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
    final file = await asset.file;
    if (file == null) return;

    final path = file.path;

    setState(() {
      if (_selectedImagePaths.contains(path)) {
        _selectedImagePaths.remove(path);
      } else {
        _selectedImagePaths.add(path);
      }
    });
  }

  void _toggleTrackSelection(Track track) {

    setState(() {
      if (_selectedTracks.contains(track)) {
        _selectedTracks.remove(track);
      } else {
        _selectedTracks.add(track);
      }
    });
  }

  void _confirmSelection() {
    widget.onMediaSelected?.call(_selectedImagePaths, _selectedTracks);
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
                const Icon(CupertinoIcons.photo, size: 16),
                const SizedBox(width: 4),
                Text(_currentAlbumName),
                const SizedBox(width: 2),
                const Icon(CupertinoIcons.chevron_down, size: 12),
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
              const Icon(CupertinoIcons.photo, size: 16),
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
            const Icon(CupertinoIcons.music_note, size: 16),
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
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.1), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text('Выберите альбом', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Закрыть', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
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

                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      _switchToAlbum(album);
                      Navigator.of(context).pop();
                    },
                    child: Row(
                      children: [
                        // Превью последнего фото или иконка
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.bgDark,
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
                                        const Icon(CupertinoIcons.photo, size: 20, color: AppColors.textSecondary),
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
                                                  const Icon(CupertinoIcons.photo, size: 20, color: AppColors.textSecondary),
                                            ),
                                          );
                                        } else {
                                          return const Icon(CupertinoIcons.photo, size: 20, color: AppColors.textSecondary);
                                        }
                                      },
                                    )
                                  : const Icon(CupertinoIcons.photo, size: 20, color: AppColors.textSecondary),
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
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // Количество фото
                              Text(
                                '${albumInfo.assetCount}',
                                style: AppTextStyles.bodySecondary.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),

                        // Индикатор выбора
                        if (isSelected)
                          Icon(CupertinoIcons.checkmark, color: context.dynamicPrimaryColor, size: 20),
                      ],
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

  bool get _hasContent => _selectedImagePaths.isNotEmpty || _selectedTracks.isNotEmpty;
  int get _totalSelected => _selectedImagePaths.length + _selectedTracks.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Заголовок с кнопками
          _buildHeader(),

          // TabBar с динамическими кнопками
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              tabs: [
                _buildPhotoTabLabel(),
                _buildMusicTabLabel(),
              ],
              labelColor: context.dynamicPrimaryColor,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: context.dynamicPrimaryColor,
              labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: AppTextStyles.bodyMedium,
            ),
          ),

          // Содержимое табов
          Expanded(
            child: TabBarView(
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
          bottom: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Закрыть', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          const Spacer(),
          Text('Добавить контент', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _hasContent ? _confirmSelection : null,
            child: Text(
              _hasContent ? 'Готово ($_totalSelected)' : 'Готово',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _hasContent ? context.dynamicPrimaryColor : AppColors.textSecondary,
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
      return const Center(child: CupertinoActivityIndicator());
    }

    if (!_hasGalleryPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text('Нет доступа к галерее', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Предоставьте разрешение для доступа к фото', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: _loadGallery,
                child: Text('Попробовать снова', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryPurple)),
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
            const Icon(CupertinoIcons.photo, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Галерея пуста', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
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
            color: AppColors.bgDark,
            child: const Center(child: CupertinoActivityIndicator()),
          );
        }

        final asset = _galleryAssets[index];
        return FutureBuilder<String?>(
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
                      image: AssetEntityImageProvider(asset, isOriginal: false, thumbnailSize: const ThumbnailSize.square(200)),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: AppColors.bgDark, child: const CupertinoActivityIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: AppColors.bgDark, child: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white));
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
                        child: const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white),
                      ),
                    ),
                  if (asset.type == AssetType.video)
                    Positioned(
                      bottom: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                        child: const Icon(CupertinoIcons.video_camera, size: 12, color: Colors.white),
                      ),
                    ),
                  if (!isSelected && _selectedImagePaths.length >= 10)
                    Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _getAssetPath(AssetEntity asset) async {
    try {
      final file = await asset.file;
      return file?.path;
    } catch (e) {
      return null;
    }
  }

  Widget _buildMusicTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Введите название трека, артиста...',
            style: const TextStyle(color: AppColors.textPrimary),
            placeholderStyle: const TextStyle(color: AppColors.textSecondary),
            backgroundColor: AppColors.bgDark,
            borderRadius: BorderRadius.circular(12),
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
      return const Center(child: CupertinoActivityIndicator());
    }

    if (state.favoritesStatus == MusicLoadStatus.failure && state.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Ошибка загрузки', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            CupertinoButton(
              onPressed: () => context.read<MusicBloc>().add(MusicFavoritesFetched()),
              child: Text('Повторить', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryPurple)),
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
            const Icon(CupertinoIcons.heart, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('У вас пока нет любимых треков', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Добавьте треки в избранное в разделе музыки', style: AppTextStyles.bodySecondary.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
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
            return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CupertinoActivityIndicator()));
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
            child: TrackListItem(
              track: track,
              onTap: () => _toggleTrackSelection(track),
              showLikeButton: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(MusicState state) {
    if (state.searchStatus == MusicLoadStatus.loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (state.searchStatus == MusicLoadStatus.failure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Ошибка поиска', style: AppTextStyles.h3.copyWith(color: AppColors.error)),
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
            const Icon(CupertinoIcons.search, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Ничего не найдено', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
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
          child: TrackListItem(
            track: track,
            onTap: () => _toggleTrackSelection(track),
            showLikeButton: false,
          ),
        );
      },
    );
  }
}
