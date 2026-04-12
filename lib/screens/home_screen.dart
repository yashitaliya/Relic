import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/photo_model.dart';
import '../widgets/photo_grid_item.dart';
import '../services/settings_service.dart';
import '../screens/settings_screen.dart';
import '../widgets/custom_notification.dart';
import 'dart:ui';
import '../services/trash_service.dart';
import '../services/saf_service.dart';
import '../services/file_manager_service.dart';
import '../widgets/album_picker_dialog.dart';
import '../widgets/styled_dialog.dart';
import '../widgets/radial_menu.dart';
import '../widgets/selection_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vault_service.dart';
import '../services/search_data_service.dart';
import '../services/selection_service.dart';
import '../services/photo_service.dart';
import '../utils/animation_utils.dart';
import '../theme/app_theme.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final SettingsService _settingsService = SettingsService();
  List<PhotoModel> _photos = [];
  final Map<String, List<PhotoModel>> _groupedPhotos = {};
  final List<String> _sortedGroupKeys = [];
  bool _isLoading = true;
  bool _hasPermission = true;
  String _sortOrder = 'newest';
  bool _isSelectionMode = false;
  final Set<String> _selectedPhotoIds = {};
  int _gridSize = 3;
  int _loadSessionId = 0;
  StreamSubscription<FavoriteChange>? _favoriteSubscription;
  StreamSubscription<void>? _settingsSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PhotoManager.addChangeCallback(_onAssetsChanged);
    PhotoManager.startChangeNotify();
    _settingsSubscription = SettingsService.changes.listen((_) {
      _loadSettings();
    });
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
    final sortOrder = await _settingsService.getSortOrder();
    if (mounted) {
      setState(() {
        _gridSize = gridSize;
        _sortOrder = sortOrder;
      });
    }
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _favoriteSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PhotoManager.removeChangeCallback(_onAssetsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPhotos(silent: true);
    }
  }

  Future<void> _loadPhotos({bool silent = false}) async {
    _loadSessionId++;
    final int currentSessionId = _loadSessionId;

    // 1. Load Cache Immediately
    if (_photos.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (_loadSessionId != currentSessionId) return;

      final cachedIds = prefs.getStringList('home_cached_ids') ?? [];
      if (cachedIds.isNotEmpty) {
        final List<PhotoModel> cachedPhotos = [];
        for (final id in cachedIds) {
          if (_loadSessionId != currentSessionId) return;
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
        if (cachedPhotos.isNotEmpty &&
            mounted &&
            _loadSessionId == currentSessionId) {
          setState(() {
            _processPhotos(cachedPhotos);
            // Keep loading true until fresh load completes or fails
            // _isLoading = false;
          });
        }
      }
    }

    // 2. Fresh Load
    if (mounted && _loadSessionId == currentSessionId && !silent) {
      setState(() => _isLoading = true);
    }

    final safService = SafService();
    final hasAllFiles = await safService.hasAllFilesAccess();

    if (!hasAllFiles) {
      final uri = await safService.getPersistedUri();
      if (uri == null) {
        if (mounted && _loadSessionId == currentSessionId) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
          });
        }
        return;
      }
    }

    final permissionState = await PhotoManager.requestPermissionExtend();
    final hasPermission =
        permissionState.isAuth || permissionState == PermissionState.limited;

    if (!hasPermission) {
      if (mounted && _loadSessionId == currentSessionId) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
      }
      return;
    }

    if (mounted && _loadSessionId == currentSessionId) {
      setState(() => _hasPermission = true);
      // Trigger global smart search scan
      SearchDataService.instance.startScan();
    }

    try {
      var albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      // Retry if empty but permission granted (common on fresh install)
      if (albums.isEmpty && hasPermission) {
        await Future.delayed(const Duration(milliseconds: 500));
        albums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          hasAll: true,
        );
      }

      if (_loadSessionId != currentSessionId) return;

      if (albums.isNotEmpty) {
        final recentAlbum = albums.first;
        final totalCount = await recentAlbum.assetCountAsync;

        // Load ALL assets at once (matching AlbumPhotosScreen logic)
        final allAssets = await recentAlbum.getAssetListRange(
          start: 0,
          end: totalCount,
        );

        final trashedIds = await TrashService().getTrashedPhotoIds();
        final favoriteIds = await PhotoService().getFavoriteIds();

        List<PhotoModel> processAssets(List<AssetEntity> assets) {
          return assets
              .where((asset) => !trashedIds.contains(asset.id))
              .where(
                (asset) =>
                    asset.type == AssetType.image ||
                    asset.type == AssetType.video,
              )
              .where((asset) {
                if (!Platform.isAndroid) {
                  return true;
                }
                final path = asset.relativePath?.toLowerCase() ?? '';
                return path.contains('dcim') || path.contains('camera');
              })
              .map(
                (asset) => PhotoModel(
                  id: asset.id,
                  asset: asset,
                  createdDate: asset.createDateTime,
                  isFavorite: favoriteIds.contains(asset.id),
                ),
              )
              .toList();
        }

        final freshPhotos = processAssets(allAssets);

        if (mounted && _loadSessionId == currentSessionId) {
          // Idempotent check: Only update if content differs
          bool needsUpdate = true;
          if (_photos.length == freshPhotos.length) {
            needsUpdate = false;
            for (int i = 0; i < _photos.length; i++) {
              if (_photos[i].id != freshPhotos[i].id) {
                needsUpdate = true;
                break;
              }
            }
          } else {
            needsUpdate = true;
          }

          if (needsUpdate) {
            setState(() {
              _processPhotos(freshPhotos);
              _isLoading = false;
            });

            // Update Cache (First 100 only)
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(
              'home_cached_ids',
              freshPhotos.take(100).map((p) => p.id).toList(),
            );
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted && _loadSessionId == currentSessionId) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && _loadSessionId == currentSessionId) {
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
    // Sort flat list first
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

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Permission Required',
          style: TextStyle(
            color: Color(0xFF6B3E26),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Relic Gallery needs full storage access to manage your photos and albums effectively.\n\nPlease grant "All Files Access" to continue.',
          style: TextStyle(color: Color(0xFF2C2C2C)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SafService().requestAllFilesAccess();
              await Future.delayed(const Duration(seconds: 1));
              _loadPhotos();
            },
            child: const Text(
              'Grant Access',
              style: TextStyle(
                color: Color(0xFFF37121),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeSortOrder(String newOrder) {
    setState(() {
      _sortOrder = newOrder;
      _processPhotos(_photos);
    });
    _settingsService.setSortOrder(newOrder);
  }

  void _onPhotoDeleted(PhotoModel photo) {
    _loadPhotos(); // Refresh entire list
  }

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

  Future<void> _deleteSelectedPhotos() async {
    final confirmed = await StyledDialog.showConfirmation(
      context: context,
      title: 'Delete Photos',
      message: 'Delete ${_selectedPhotoIds.length} photos?',
      confirmText: 'Delete',
      isDestructive: true,
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
      for (final photo in _photos) {
        if (_selectedPhotoIds.contains(photo.id)) {
          final file = await photo.asset.file;
          if (file != null) {
            filesToShare.add(XFile(file.path));
          }
        }
      }

      if (filesToShare.isEmpty) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'No files to share',
            type: NotificationType.error,
          );
        }
        return;
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        filesToShare,
        text: 'Sharing ${filesToShare.length} photos',
      );

      setState(() {
        _isSelectionMode = false;
        _selectedPhotoIds.clear();
        SelectionService.instance.endSelection();
      });
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Failed to share photos',
          type: NotificationType.error,
        );
      }
    }
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

    final newName = await StyledDialog.showTextInput(
      context: context,
      title: 'Rename Image',
      hintText: 'New Name',
      initialValue: file.uri.pathSegments.last,
      confirmText: 'Rename',
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != file.uri.pathSegments.last) {
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
      builder: (context) => const AlbumPickerDialog(title: 'Copy to Album'),
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
          SelectionService.instance.endSelection();
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
      builder: (context) => const AlbumPickerDialog(title: 'Move to Album'),
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
          await fileManager.moveImageToFolder(photo.asset, targetFolder);
          successCount++;
        } catch (e) {
          debugPrint('Failed to move ${photo.id}: $e');
        }
      }

      if (mounted) {
        final verb = Platform.isIOS ? 'Added' : 'Moved';
        CustomNotification.show(
          context,
          message: '$verb $successCount photos to "$targetFolder"',
          type: NotificationType.success,
        );

        setState(() {
          _isSelectionMode = false;
          _selectedPhotoIds.clear();
          SelectionService.instance.endSelection();
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

  Future<void> _hideSelectedPhotos() async {
    final confirmed = await StyledDialog.showConfirmation(
      context: context,
      title: 'Hide Photos',
      message:
          'Hide ${_selectedPhotoIds.length} photos? They will be moved to the Vault.',
      confirmText: 'Hide',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        final vaultService = VaultService();
        int successCount = 0;

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
            _processPhotos(_photos);
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
    super.build(context);
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
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Relic',
                                style: TextStyle(
                                  color: Color(0xFF6B3E26),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
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
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: Color(0xFF6B3E26),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen(),
                                  ),
                                ),
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
          : !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_off_outlined,
                    size: 80,
                    color: Color(0xFFF37121),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Permission Required',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B3E26),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Relic needs access to your photos and videos to display them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _showPermissionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37121),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Grant Access'),
                  ),
                ],
              ),
            )
          : _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Scanning for photos...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : SmoothRefreshIndicator(
              onRefresh: _loadPhotos,
              child: CustomScrollView(
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
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                                isSelected: _selectedPhotoIds.contains(
                                  photo.id,
                                ),
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
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isSelectionMode && _selectedPhotoIds.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(
                bottom: AppTheme.selectionFabBottomPaddingWithBottomNav,
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
                    icon: Icons.drive_file_move_outline,
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

    // Add year for Today/Yesterday if different year (edge case)
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
