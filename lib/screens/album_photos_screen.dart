import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/photo_model.dart';
import '../widgets/photo_grid_item.dart';
import '../services/settings_service.dart';
import '../widgets/custom_notification.dart';
import '../widgets/styled_dialog.dart';
import '../services/trash_service.dart';
import '../widgets/selection_sheet.dart';
import '../services/file_manager_service.dart';
import '../widgets/album_picker_dialog.dart';
import '../widgets/radial_menu.dart';
import '../services/selection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vault_service.dart';
import '../services/photo_service.dart';
import '../theme/app_theme.dart';
import 'dart:async';

class AlbumPhotosScreen extends StatefulWidget {
  final AlbumModel album;
  final List<AssetEntity>? preloadedAssets;
  final int? initialIndex;

  const AlbumPhotosScreen({
    super.key,
    required this.album,
    this.preloadedAssets,
    this.initialIndex,
  });

  @override
  State<AlbumPhotosScreen> createState() => _AlbumPhotosScreenState();
}

class _AlbumPhotosScreenState extends State<AlbumPhotosScreen>
    with WidgetsBindingObserver {
  final SettingsService _settingsService = SettingsService();
  List<PhotoModel> _photos = [];
  final Map<String, List<PhotoModel>> _groupedPhotos = {};
  final List<String> _sortedGroupKeys = [];
  bool _isLoading = true;
  String _sortOrder = 'newest';

  // Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedPhotoIds = {};
  int _gridSize = 3;
  StreamSubscription<FavoriteChange>? _favoriteSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PhotoManager.addChangeCallback(_onAssetsChanged);
    PhotoManager.startChangeNotify();
    _loadSettings();
    _loadPhotos();
    _favoriteSubscription = PhotoService.onFavoriteChanged.listen(
      _onFavoriteChanged,
    );
  }

  void _onFavoriteChanged(FavoriteChange event) {
    if (!mounted) return;
    setState(() {
      final index = _photos.indexWhere((p) => p.id == event.id);
      if (index != -1) {
        _photos[index].isFavorite = event.isFavorite;
      }
    });
  }

  void _onAssetsChanged(MethodCall call) {
    _loadPhotos();
  }

  Future<void> _loadSettings() async {
    final gridSize = await _settingsService.getGridSize();
    if (mounted) {
      setState(() {
        _gridSize = gridSize;
      });
    }
  }

  @override
  void dispose() {
    _favoriteSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PhotoManager.removeChangeCallback(_onAssetsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPhotos();
    }
  }

  Future<void> _loadPhotos() async {
    // 1. Load Cache Immediately
    if (_photos.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'album_photos_${widget.album.id}';
      final cachedIds = prefs.getStringList(cacheKey) ?? [];

      if (cachedIds.isNotEmpty) {
        List<PhotoModel> cachedPhotos = [];
        for (String id in cachedIds) {
          final asset = await AssetEntity.fromId(id);
          if (asset != null) {
            cachedPhotos.add(
              PhotoModel(
                id: asset.id,
                asset: asset,
                createdDate: asset.createDateTime,
                isFavorite: false,
              ),
            );
          }
        }

        if (cachedPhotos.isNotEmpty && mounted) {
          final sortOrder = await _settingsService.getAlbumSortOrder(
            widget.album.id,
          );
          _sortOrder = sortOrder;
          _processPhotos(cachedPhotos);
          setState(() {
            _isLoading = false;
          });
        }
      }
    }

    // 2. Fresh Load
    if (mounted) setState(() => _isLoading = true);

    try {
      List<AssetEntity> photoAssets = [];

      if (widget.preloadedAssets != null) {
        photoAssets = widget.preloadedAssets!;
      } else if (widget.album.pathEntity != null) {
        final totalCount = await widget.album.pathEntity!.assetCountAsync;
        photoAssets = await widget.album.pathEntity!.getAssetListRange(
          start: 0,
          end: totalCount,
        );
      }

      final trashService = TrashService();
      final trashedIds = await trashService.getTrashedPhotoIds();
      final photoService = PhotoService();
      final favoriteIds = await photoService.getFavoriteIds();

      final photos = <PhotoModel>[];
      for (var asset in photoAssets) {
        if (trashedIds.contains(asset.id)) continue;
        if (asset.type != AssetType.image && asset.type != AssetType.video) {
          continue;
        }

        photos.add(
          PhotoModel(
            id: asset.id,
            asset: asset,
            createdDate: asset.createDateTime,
            isFavorite: favoriteIds.contains(asset.id),
          ),
        );
      }

      final sortOrder = await _settingsService.getAlbumSortOrder(
        widget.album.id,
      );
      _sortOrder = sortOrder;
      _processPhotos(photos);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Update Cache (Limit to 100 items to save space)
        if (widget.album.pathEntity != null) {
          // Only cache real albums
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = 'album_photos_${widget.album.id}';
          final idsToCache = photos.take(100).map((p) => p.id).toList();
          await prefs.setStringList(cacheKey, idsToCache);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          message: 'Error: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  void _processPhotos(List<PhotoModel> photos) {
    switch (_sortOrder) {
      case 'newest':
        photos.sort((a, b) => b.createdDate.compareTo(a.createdDate));
        break;
      case 'oldest':
        photos.sort((a, b) => a.createdDate.compareTo(b.createdDate));
        break;
      case 'name':
        photos.sort((a, b) => a.id.compareTo(b.id));
        break;
    }

    _photos = photos;
    _groupPhotos();
  }

  void _groupPhotos() {
    _groupedPhotos.clear();
    _sortedGroupKeys.clear();

    if (_sortOrder == 'name') {
      _groupedPhotos['All Photos'] = _photos;
      _sortedGroupKeys.add('All Photos');
      return;
    }

    for (var photo in _photos) {
      final date = photo.createdDate;
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (!_groupedPhotos.containsKey(key)) {
        _groupedPhotos[key] = [];
        _sortedGroupKeys.add(key);
      }
      _groupedPhotos[key]!.add(photo);
    }
  }

  void _changeSortOrder(String newOrder) {
    setState(() {
      _sortOrder = newOrder;
      _processPhotos(_photos);
    });
    _settingsService.setAlbumSortOrder(widget.album.id, newOrder);
  }

  void _onPhotoDeleted(PhotoModel photo) {
    _loadPhotos(); // Refresh list to show new edits or remove deleted items
  }

  // Selection Methods
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (_isSelectionMode) {
        SelectionService.instance.startSelection();
      } else {
        _selectedPhotoIds.clear();
        SelectionService.instance.endSelection();
      }
    });
  }

  void _onPhotoSelected(PhotoModel photo) {
    setState(() {
      if (_selectedPhotoIds.contains(photo.id)) {
        _selectedPhotoIds.remove(photo.id);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectionMode = false;
          SelectionService.instance.endSelection();
        }
      } else {
        _selectedPhotoIds.add(photo.id);
        if (!_isSelectionMode) {
          _isSelectionMode = true;
          SelectionService.instance.startSelection();
        }
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPhotoIds.length == _photos.length) {
        _selectedPhotoIds.clear();
        _isSelectionMode = false;
        SelectionService.instance.endSelection();
      } else {
        _selectedPhotoIds.clear();
        _selectedPhotoIds.addAll(_photos.map((p) => p.id));
      }
    });
  }

  Future<void> _renameSelectedImage() async {
    if (Platform.isIOS) {
      CustomNotification.show(
        context,
        message: 'Renaming is not supported on iOS',
        type: NotificationType.info,
      );
      return;
    }
    if (_selectedPhotoIds.length != 1) return;

    final photoId = _selectedPhotoIds.first;
    final photo = _photos.firstWhere((p) => p.id == photoId);
    final file = await photo.asset.file;
    if (file == null) return;
    if (!mounted) return;

    final currentName = file.uri.pathSegments.last;
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Image'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'New Name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF37121)),
            ),
          ),
          autofocus: true,
          cursorColor: const Color(0xFFF37121),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(
              'Rename',
              style: TextStyle(color: Color(0xFFF37121)),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      try {
        final fileManager = FileManagerService();
        await fileManager.renameImage(photo.asset, newName);

        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Image renamed successfully',
            type: NotificationType.success,
          );
        }

        setState(() {
          _isSelectionMode = false;
          _selectedPhotoIds.clear();
          SelectionService.instance.endSelection();
        });
        _loadPhotos();
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Failed to rename: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _copySelectedPhotos() async {
    final targetFolder = await showDialog<String>(
      context: context,
      builder: (context) => AlbumPickerDialog(
        title: 'Copy to Album',
        excludeFolders: [widget.album.name], // Exclude current album
      ),
    );

    if (targetFolder == null) return;
    if (!mounted) return;

    try {
      final fileManager = FileManagerService();
      int successCount = 0;

      CustomNotification.show(
        context,
        message: 'Copying ${_selectedPhotoIds.length} photos...',
        type: NotificationType.info,
      );

      for (final id in _selectedPhotoIds) {
        final photo = _photos.firstWhere((p) => p.id == id);
        try {
          await fileManager.copyImageToFolder(photo.asset, targetFolder);
          successCount++;
        } catch (e) {
          debugPrint('Failed to copy ${photo.id}: $e');
        }
      }

      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Copied $successCount photos to "$targetFolder"',
          type: NotificationType.success,
        );

        setState(() {
          _isSelectionMode = false;
          _selectedPhotoIds.clear();
        });
        _loadPhotos();
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error copying photos: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _moveSelectedPhotos() async {
    final targetFolder = await showDialog<String>(
      context: context,
      builder: (context) => AlbumPickerDialog(
        title: 'Move to Album',
        excludeFolders: [widget.album.name], // Exclude current album
      ),
    );

    if (targetFolder == null) return;
    if (!mounted) return;

    try {
      final fileManager = FileManagerService();
      int successCount = 0;

      CustomNotification.show(
        context,
        message: 'Moving ${_selectedPhotoIds.length} photos...',
        type: NotificationType.info,
      );

      for (final id in _selectedPhotoIds) {
        final photo = _photos.firstWhere((p) => p.id == id);
        try {
          await fileManager.moveImageToFolder(
            photo.asset,
            targetFolder,
            fromAlbum: widget.album.pathEntity,
          );
          successCount++;
        } catch (e) {
          debugPrint('Failed to move ${photo.id}: $e');
        }
      }

      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Moved $successCount photos to "$targetFolder"',
          type: NotificationType.success,
        );

        setState(() {
          _isSelectionMode = false;
          _selectedPhotoIds.clear();
        });
        _loadPhotos();
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error moving photos: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text('Delete ${_selectedPhotoIds.length} photos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final trashService = TrashService();
        for (final id in _selectedPhotoIds) {
          await trashService.moveToTrash(id);
        }

        setState(() {
          _photos.removeWhere((p) => _selectedPhotoIds.contains(p.id));
          _processPhotos(_photos); // Re-group
          _isSelectionMode = false;
          _selectedPhotoIds.clear();
          SelectionService.instance.endSelection();
        });

        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Photos moved to trash',
            type: NotificationType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Failed to delete photos',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _shareSelectedPhotos() async {
    try {
      CustomNotification.show(
        context,
        message: 'Preparing ${_selectedPhotoIds.length} photos for sharing...',
        type: NotificationType.info,
      );

      final List<XFile> filesToShare = [];

      final selectedPhotos = _photos
          .where((p) => _selectedPhotoIds.contains(p.id))
          .toList();

      for (var photo in selectedPhotos) {
        final file = await photo.asset.file;
        if (file != null) {
          filesToShare.add(XFile(file.path));
        }
      }

      if (filesToShare.isEmpty) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'No files found to share',
            type: NotificationType.error,
          );
        }
        return;
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles(filesToShare, text: 'Shared via Relic Gallery');

      _toggleSelectionMode();
      // _toggleSelectionMode handles endSelection
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Failed to share photos: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _hideSelectedPhotos() async {
    final confirmed = await StyledDialog.showConfirmation(
      context: context,
      title: 'Hide Photos',
      message:
          'Hide ${_selectedPhotoIds.length} photos? They will be moved to the Vault.',
      confirmText: 'Hide',
    );

    if (confirmed == true) {
      try {
        final vaultService = VaultService();
        int successCount = 0;

        if (!mounted) return;

        CustomNotification.show(
          context,
          message: 'Hiding ${_selectedPhotoIds.length} photos...',
          type: NotificationType.info,
        );

        for (final id in _selectedPhotoIds) {
          final photo = _photos.firstWhere((p) => p.id == id);
          try {
            await vaultService.hideFile(photo.asset);
            successCount++;
            // Emit hidden change event for vault refresh
            PhotoService.emitHiddenChange(photo.id, true);
          } catch (e) {
            debugPrint('Failed to hide ${photo.id}: $e');
          }
        }

        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Hidden $successCount photos',
            type: NotificationType.success,
          );

          setState(() {
            _photos.removeWhere((p) => _selectedPhotoIds.contains(p.id));
            _isSelectionMode = false;
            _selectedPhotoIds.clear();
            SelectionService.instance.endSelection();
          });
        }
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Error hiding photos: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: _toggleSelectionMode,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedPhotoIds.length == _photos.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: Colors.black,
                  ),
                  onPressed: _selectAll,
                  tooltip: _selectedPhotoIds.length == _photos.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.black),
                  onPressed: _shareSelectedPhotos,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.black),
                  onPressed: _deleteSelectedPhotos,
                ),
              ],
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Color(0xFF6B3E26),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.album.name,
                                  style: const TextStyle(
                                    color: Color(0xFF6B3E26),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.sort,
                                  color: Color(0xFF6B3E26),
                                ),
                                onPressed: () {
                                  SelectionSheet.show(
                                    context,
                                    title: 'Sort By',
                                    options: ['newest', 'oldest', 'name'],
                                    selectedValue: _sortOrder,
                                    onSelected: _changeSortOrder,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 110 + MediaQuery.of(context).padding.top + 16,
                  ),
                ),
                ..._sortedGroupKeys.map((key) {
                  final groupPhotos = _groupedPhotos[key]!;
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(child: _buildDateHeader(key)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _gridSize,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final photo = groupPhotos[index];
                            return PhotoGridItem(
                              photo: photo,
                              index: _photos.indexOf(photo), // Global index
                              allPhotos: _photos, // Pass full list for swipe
                              isSelectionMode: _isSelectionMode,
                              isSelected: _selectedPhotoIds.contains(photo.id),
                              onPhotoSelected: _onPhotoSelected,
                              onSelectionModeStarted: () => setState(() {
                                _isSelectionMode = true;
                                SelectionService.instance.startSelection();
                              }),
                              onPhotoDeleted: _onPhotoDeleted,
                              onRefresh: _loadPhotos,
                            );
                          }, childCount: groupPhotos.length),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ), // Spacing between groups
                    ],
                  );
                }),
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isSelectionMode && _selectedPhotoIds.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(
                bottom: AppTheme.selectionFabBottomPadding,
              ),
              child: RadialMenu(
                icon: Icons.more_horiz,
                activeIcon: Icons.close,
                startAngle: 180,
                endAngle: 270,
                radius: 120, // Increase radius to prevent label overlap
                children: [
                  RadialMenuChild(
                    icon: Icons.drive_file_rename_outline,
                    onPressed: _renameSelectedImage,
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                  RadialMenuChild(
                    icon: Icons.copy,
                    onPressed: _copySelectedPhotos,
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                  RadialMenuChild(
                    icon: Icons.drive_file_move,
                    onPressed: _moveSelectedPhotos,
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                  RadialMenuChild(
                    icon: Icons.lock_outline,
                    onPressed: _hideSelectedPhotos,
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDateHeader(String key) {
    if (key == 'All Photos') return const SizedBox.shrink();

    final date = DateTime.parse(key);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String title;
    if (dateOnly == today) {
      title = 'Today';
    } else if (dateOnly == yesterday) {
      title = 'Yesterday';
    } else {
      title = DateFormat('MMM dd, yyyy').format(date);
    }

    // Add year for Today/Yesterday if different year
    if (date.year != now.year && (title == 'Today' || title == 'Yesterday')) {
      title += ', ${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B3E26),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('EEEE').format(date),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
