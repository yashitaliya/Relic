import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/photo_model.dart';
import '../widgets/folder_card.dart';
import 'settings_screen.dart';
import 'album_photos_screen.dart';

import '../widgets/custom_notification.dart';
import '../services/trash_service.dart';
import '../services/file_manager_service.dart';
import '../widgets/styled_dialog.dart';
import '../widgets/radial_menu.dart';
import '../services/saf_service.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/settings_service.dart';
import '../services/selection_service.dart';

import '../utils/animation_utils.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  List<AlbumModel> _albums = [];
  List<AlbumModel> _filteredAlbums = [];
  bool _isLoading = true;
  bool _hasPermission = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isInlineSearchActive = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedAlbumIds = {};
  final FileManagerService _fileManager = FileManagerService();
  int _gridSize = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PhotoManager.addChangeCallback(_onAssetsChanged);
    PhotoManager.startChangeNotify();
    _loadAlbums();
    _loadGridSize();
    _searchController.addListener(_onSearchChanged);
  }

  void _onAssetsChanged(MethodCall call) {
    _loadAlbums(silent: true);
  }

  Future<void> _loadGridSize() async {
    final size = await SettingsService().getAlbumsGridSize();
    if (mounted) {
      setState(() => _gridSize = size);
    }
  }

  Future<void> _toggleGridSize() async {
    final newSize = _gridSize == 2 ? 3 : 2;
    await SettingsService().setAlbumsGridSize(newSize);
    if (mounted) {
      setState(() => _gridSize = newSize);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PhotoManager.removeChangeCallback(_onAssetsChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAlbums(silent: true);
    }
  }

  Future<void> _loadAlbums({bool silent = false}) async {
    // 1. Load Cache Immediately
    if (_albums.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('albums_cache');
      if (cachedData != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedData);
          final List<AlbumModel> cachedAlbums = [];

          for (var item in decoded) {
            final thumbnailId = item['thumbnailId'];
            AssetEntity? thumbnail;
            if (thumbnailId != null) {
              thumbnail = await AssetEntity.fromId(thumbnailId);
            }

            cachedAlbums.add(
              AlbumModel(
                id: item['id'],
                name: item['name'],
                photoCount: item['count'],
                pathEntity:
                    null, // PathEntity not available from cache, but not needed for display
                thumbnailAsset: thumbnail,
              ),
            );
          }

          final visibleCachedAlbums = cachedAlbums
              .where((album) => album.photoCount > 0)
              .toList();

          if (visibleCachedAlbums.isNotEmpty && mounted) {
            setState(() {
              _albums = visibleCachedAlbums;
              _filteredAlbums = _searchQuery.isEmpty
                  ? visibleCachedAlbums
                  : visibleCachedAlbums
                        .where(
                          (album) => album.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
              _isLoading = false;
            });
          }
        } catch (e) {
          debugPrint('Error loading album cache: $e');
        }
      }
    }

    // 2. Fresh Load
    if (mounted && !silent) {
      setState(() => _isLoading = true);
    }

    try {
      // Check for All Files Access first
      final safService = SafService();
      final hasAllFiles = await safService.hasAllFilesAccess();

      if (!hasAllFiles) {
        // Check if we have a persisted URI as fallback
        final uri = await safService.getPersistedUri();
        if (uri == null) {
          if (mounted) {
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
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _hasPermission = true);
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      List<AlbumModel> albumModels = [];

      final trashService = TrashService();
      final trashedIds = await trashService.getTrashedPhotoIds();

      // Verify trash IDs exist to avoid subtracting stale IDs
      int validTrashCount = 0;
      if (trashedIds.isNotEmpty) {
        final validTrashFutures = trashedIds.map(
          (id) => AssetEntity.fromId(id),
        );
        final validTrashAssets = await Future.wait(validTrashFutures);
        validTrashCount = validTrashAssets.where((a) => a != null).length;
      }

      for (var album in albums) {
        final assetCount = await album.assetCountAsync;
        // Fetch more assets to find 3 valid thumbnails
        final assets = await album.getAssetListRange(start: 0, end: 20);

        AssetEntity? thumbnail;
        List<AssetEntity> thumbnails = [];

        for (var asset in assets) {
          if (!trashedIds.contains(asset.id) &&
              (asset.type == AssetType.image ||
                  asset.type == AssetType.video)) {
            if (thumbnail == null) {
              thumbnail = asset;
            }
            thumbnails.add(asset);
            if (thumbnails.length >= 3) break;
          }
        }

        // Adjust count for trashed items
        int adjustedCount = assetCount;
        if (album.isAll) {
          adjustedCount = assetCount - validTrashCount;
          if (adjustedCount < 0) adjustedCount = 0;
        }

        if (adjustedCount == 0) {
          continue;
        }

        albumModels.add(
          AlbumModel(
            id: album.id,
            name: album.name,
            photoCount: adjustedCount,
            pathEntity: album,
            thumbnailAsset: thumbnail,
            thumbnailAssets: thumbnails.isNotEmpty ? thumbnails : null,
          ),
        );
      }

      // Sort albums: Recent, Camera, Videos, Screenshots, then others
      albumModels.sort((a, b) {
        int getPriority(String name) {
          final n = name.toLowerCase();
          if (n == 'recent' || n == 'recents' || n == 'all') return 0;
          if (n == 'camera') return 1;
          if (n == 'videos' || n == 'video') return 2;
          if (n == 'screenshots' || n == 'screenshot') return 3;
          return 4;
        }

        final pA = getPriority(a.name);
        final pB = getPriority(b.name);
        if (pA != pB) return pA.compareTo(pB);
        return a.name.compareTo(b.name);
      });

      if (mounted) {
        setState(() {
          _albums = albumModels;
          _filteredAlbums = _searchQuery.isEmpty
              ? albumModels
              : albumModels
                    .where(
                      (album) => album.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();
          _isLoading = false;
        });

        // Update Cache
        final prefs = await SharedPreferences.getInstance();
        final cacheList = albumModels
            .map(
              (a) => {
                'id': a.id,
                'name': a.name,
                'count': a.photoCount,
                'thumbnailId': a.thumbnailAsset?.id,
              },
            )
            .toList();
        await prefs.setString('albums_cache', jsonEncode(cacheList));
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error loading albums: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          'Relic Gallery needs full storage access to manage your albums effectively.\n\nPlease grant "All Files Access" to continue.',
          style: TextStyle(color: Color(0xFF2C2C2C)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SafService().requestAllFilesAccess();
              await Future.delayed(const Duration(seconds: 1));
              _loadAlbums();
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

  void _onSearchChanged() {
    final query = _searchController.text;
    _applySearchQuery(query, syncController: false);
  }

  void _applySearchQuery(String query, {bool syncController = true}) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAlbums = _albums;
      } else {
        _filteredAlbums = _albums
            .where(
              (album) => album.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });

    if (syncController && _searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
  }

  void _startInlineSearch() {
    setState(() {
      _isInlineSearchActive = true;
      _searchController.value = TextEditingValue(
        text: _searchQuery,
        selection: TextSelection.collapsed(offset: _searchQuery.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _stopInlineSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _isInlineSearchActive = false;
    });
    _clearSearch();
  }

  void _clearSearch() {
    _applySearchQuery('');
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (_isSelectionMode) {
        SelectionService.instance.startSelection();
      } else {
        _selectedAlbumIds.clear();
        SelectionService.instance.endSelection();
      }
    });
  }

  void _onAlbumSelected(AlbumModel album) {
    setState(() {
      if (_selectedAlbumIds.contains(album.id)) {
        _selectedAlbumIds.remove(album.id);
        if (_selectedAlbumIds.isEmpty) {
          _isSelectionMode = false;
          SelectionService.instance.endSelection();
        }
      } else {
        _selectedAlbumIds.add(album.id);
        if (!_isSelectionMode) {
          _isSelectionMode = true;
          SelectionService.instance.startSelection();
        }
      }
    });
  }

  Future<void> _deleteSelectedAlbums() async {
    final confirmed = await StyledDialog.showConfirmation(
      context: context,
      title: 'Delete Albums',
      message: 'Delete ${_selectedAlbumIds.length} albums?',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Album deletion not supported on this platform',
        type: NotificationType.info,
      );
      _toggleSelectionMode();
    }
  }

  Future<_PickedAlbumSelection?> _showPhotoPickerForFolder(
    String folderName,
  ) async {
    // Get all albums for browsing
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Get both images and videos
    );

    if (albums.isEmpty) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'No albums found',
          type: NotificationType.info,
        );
      }
      return null;
    }

    // Show album-based photo picker dialog
    if (!mounted) return null;
    final selection = await showDialog<_PickedAlbumSelection>(
      context: context,
      builder: (context) => _AlbumPhotoPickerDialog(albums: albums),
    );

    return selection;
  }

  Future<void> _renameFolder() async {
    if (Platform.isIOS) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Renaming albums is not supported on iOS',
          type: NotificationType.info,
        );
      }
      return;
    }
    // Show dialog to select folder and enter new name
    final controller = TextEditingController();

    // Get list of folders in Pictures
    final folders = await _fileManager.getPicturesFolders();

    if (folders.isEmpty) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'No folders found in Pictures',
          type: NotificationType.info,
        );
      }
      return;
    }

    // Pre-select if exactly one album is selected
    String? selectedFolder;
    if (_isSelectionMode && _selectedAlbumIds.length == 1) {
      final selectedId = _selectedAlbumIds.first;
      try {
        final album = _filteredAlbums.firstWhere((a) => a.id == selectedId);
        if (folders.contains(album.name)) {
          selectedFolder = album.name;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rename Folder'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedFolder,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Folder',
                      border: OutlineInputBorder(),
                    ),
                    items: folders.map((folder) {
                      return DropdownMenuItem(
                        value: folder,
                        child: Text(folder, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedFolder = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'New Folder Name',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF37121)),
                      ),
                    ),
                    cursorColor: const Color(0xFFF37121),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'oldName': selectedFolder ?? '',
                'newName': controller.text,
              }),
              child: const Text(
                'Rename',
                style: TextStyle(color: Color(0xFFF37121)),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null &&
        result['oldName']!.isNotEmpty &&
        result['newName']!.isNotEmpty) {
      if (!mounted) return;
      final oldName = result['oldName']!;
      final newName = result['newName']!;

      try {
        final success = await _fileManager.renameFolder(oldName, newName);
        if (success) {
          if (mounted) {
            CustomNotification.show(
              context,
              message: 'Folder renamed to "$newName"',
              type: NotificationType.success,
            );
          }
          _loadAlbums();
        } else {
          if (mounted) {
            CustomNotification.show(
              context,
              message: 'Failed to rename folder',
              type: NotificationType.error,
            );
          }
        }
      } catch (e) {
        String errorMessage = e.toString();
        if (errorMessage.contains("message: ")) {
          errorMessage = errorMessage
              .split("message: ")
              .last
              .replaceAll("'", "");
        }
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Error: $errorMessage',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _createAlbum() async {
    final controller = TextEditingController();

    // Step 1: Get folder name
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Folder Name',
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
              'Next',
              style: TextStyle(color: Color(0xFFF37121)),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    // Step 2: Pick photos FIRST
    final picked = await _showPhotoPickerForFolder(name);

    if (picked == null || picked.assets.isEmpty) {
      // User cancelled or no photos selected - don't create folder
      return;
    }
    if (!mounted) return;

    // Step 2.5: Ask Move or Copy
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move or Copy?'),
        content: const Text(
          'Do you want to move or copy these photos to the new folder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Copy',
              style: TextStyle(color: Color(0xFFF37121)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Move',
              style: TextStyle(color: Color(0xFFF37121)),
            ),
          ),
        ],
      ),
    );

    if (shouldMove == null) return; // User cancelled
    if (!mounted) return;

    // Step 3: Create folder ONLY if photos were selected
    try {
      if (Platform.isAndroid) {
        // Use FileManagerService (SAF) to create folder
        final success = await _fileManager.createFolderIfNotExists(name);

        if (!success) {
          throw Exception('Failed to create folder via SAF');
        }

        // Wait for filesystem to register the new folder
        await Future.delayed(const Duration(milliseconds: 500));

        // Step 4: Move or Copy selected photos to new folder
        int successCount = 0;
        for (var photo in picked.assets) {
          try {
            if (shouldMove) {
              await _fileManager.moveImageToFolder(photo, name);
            } else {
              await _fileManager.copyImageToFolder(photo, name);
            }
            // result is null on success (as per FileManagerService implementation returning null on success)
            // Wait, FileManagerService returns AssetEntity? but implementation returns null on success?
            // Let's check FileManagerService again.
            // It returns null on success.
            successCount++;
          } catch (e) {
            debugPrint(
              'Failed to ${shouldMove ? "move" : "copy"} ${photo.id}: $e',
            );
          }
        }

        // Clear cache and refresh
        await PhotoManager.clearFileCache();

        if (mounted) {
          CustomNotification.show(
            context,
            message:
                'Folder "$name" created with $successCount photo${successCount != 1 ? 's' : ''}',
            type: NotificationType.success,
          );
        }

        _loadAlbums();
      } else {
        final permissionState = await PhotoManager.requestPermissionExtend();
        if (permissionState == PermissionState.limited) {
          // iOS Limited Photos access can block album creation / adding assets.
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Allow Full Photos Access'),
                content: const Text(
                  'To create a new album and add photos, please allow access to more photos in iOS Settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await PhotoManager.presentLimited(
                        type: RequestType.common,
                      );
                    },
                    child: const Text('Manage Access'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await PhotoManager.openSetting();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
        }

        final entity = await PhotoManager.editor.darwin.createAlbum(name);
        if (entity == null) {
          throw Exception('Failed to create album');
        }

        int successCount = 0;
        for (final asset in picked.assets) {
          try {
            await PhotoManager.editor.copyAssetToPath(
              asset: asset,
              pathEntity: entity,
            );
            successCount++;
          } catch (e) {
            debugPrint('Failed to add ${asset.id} to $name: $e');
          }
        }

        if (shouldMove == true) {
          try {
            final sourceType = picked.sourceAlbum.albumTypeEx?.darwin?.type;
            final isSmart =
                sourceType == PMDarwinAssetCollectionType.smartAlbum;

            if (!picked.sourceAlbum.isAll && !isSmart) {
              await PhotoManager.editor.darwin.removeAssetsInAlbum(
                picked.assets,
                picked.sourceAlbum,
              );
            }
          } catch (e) {
            debugPrint('Failed to remove moved assets from source album: $e');
          }
        }

        await PhotoManager.clearFileCache();

        if (mounted) {
          CustomNotification.show(
            context,
            message:
                'Album "$name" created with $successCount photo${successCount != 1 ? 's' : ''}',
            type: NotificationType.success,
          );
        }

        _loadAlbums();
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error creating album: ${e.toString()}',
          type: NotificationType.error,
        );
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
              title: Text(
                '${_selectedAlbumIds.length} Selected',
                style: const TextStyle(color: Colors.black, fontSize: 18),
              ),
              elevation: 1,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.black),
                  onPressed: () {
                    CustomNotification.show(
                      context,
                      message: 'Sharing albums not supported yet',
                      type: NotificationType.info,
                    );
                    _toggleSelectionMode();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.black),
                  onPressed: _deleteSelectedAlbums,
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
                              if (_isInlineSearchActive)
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onChanged: (value) => _applySearchQuery(
                                      value,
                                      syncController: false,
                                    ),
                                    textInputAction: TextInputAction.search,
                                    cursorColor: const Color(0xFF6B3E26),
                                    style: const TextStyle(
                                      color: Color(0xFF6B3E26),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search albums...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF9E8A7A),
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  'Albums',
                                  style: TextStyle(
                                    color: Color(0xFF6B3E26),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (!_isInlineSearchActive) const Spacer(),
                              if (!_isInlineSearchActive)
                                IconButton(
                                  icon: Icon(
                                    _gridSize == 2
                                        ? Icons.grid_view
                                        : Icons.view_comfy,
                                    color: const Color(0xFF6B3E26),
                                    size: 24,
                                  ),
                                  onPressed: _toggleGridSize,
                                  tooltip: 'Change Grid Size',
                                ),
                              if (!_isInlineSearchActive)
                                IconButton(
                                  icon: const Icon(
                                    Icons.search,
                                    color: Color(0xFF6B3E26),
                                    size: 24,
                                  ),
                                  onPressed: _startInlineSearch,
                                  tooltip: 'Search Albums',
                                ),
                              if (_isInlineSearchActive)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF6B3E26),
                                    size: 22,
                                  ),
                                  onPressed: _stopInlineSearch,
                                  tooltip: 'Clear Search',
                                ),
                              if (!_isInlineSearchActive)
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings,
                                    color: Color(0xFF6B3E26),
                                    size: 24,
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
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
            : Stack(
                children: [
                  SmoothRefreshIndicator(
                    onRefresh: _loadAlbums,
                    child: AnimationLimiter(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height:
                                  110 + MediaQuery.of(context).padding.top + 16,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _filteredAlbums.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_album_outlined,
                                          size: 80,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'No albums found'
                                              : 'No matching albums',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: _gridSize,
                                          childAspectRatio: _gridSize == 2
                                              ? 0.78
                                              : 0.72,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final album = _filteredAlbums[index];
                                      final isSelected = _selectedAlbumIds
                                          .contains(album.id);

                                      return AnimationConfiguration.staggeredGrid(
                                        position: index,
                                        duration: const Duration(
                                          milliseconds: 375,
                                        ),
                                        columnCount: _gridSize,
                                        child: ScaleAnimation(
                                          child: FadeInAnimation(
                                            child: FolderCard(
                                              album: album,
                                              gridSize: _gridSize,
                                              isSelectionMode: _isSelectionMode,
                                              isSelected: isSelected,
                                              onTap: () {
                                                if (_isSelectionMode) {
                                                  _onAlbumSelected(album);
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          AlbumPhotosScreen(
                                                            album: album,
                                                          ),
                                                    ),
                                                  ).then(
                                                    (_) => _loadAlbums(
                                                      silent: true,
                                                    ),
                                                  );
                                                }
                                              },
                                              onLongPress: () =>
                                                  _onAlbumSelected(album),
                                            ),
                                          ),
                                        ),
                                      );
                                    }, childCount: _filteredAlbums.length),
                                  ),
                                ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 120),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _isSelectionMode
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 15,
              ),
              child: RadialMenu(
                icon: Icons.more_horiz,
                activeIcon: Icons.close,
                anchorLeft: true,
                startAngle: 300,
                endAngle: 340,
                radius: 100,
                children: [
                  RadialMenuChild(
                    icon: Icons.drive_file_rename_outline,
                    onPressed: _renameFolder,
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                  RadialMenuChild(
                    icon: Icons.create_new_folder,
                    onPressed: _createAlbum,
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// Album-based Photo Picker Dialog - Two screen flow
// First screen shows album grid, second screen shows photos from selected album
class _PickedAlbumSelection {
  final AssetPathEntity sourceAlbum;
  final List<AssetEntity> assets;

  const _PickedAlbumSelection({
    required this.sourceAlbum,
    required this.assets,
  });
}

class _AlbumPhotoPickerDialog extends StatefulWidget {
  final List<AssetPathEntity> albums;

  const _AlbumPhotoPickerDialog({required this.albums});

  @override
  State<_AlbumPhotoPickerDialog> createState() =>
      _AlbumPhotoPickerDialogState();
}

class _AlbumPhotoPickerDialogState extends State<_AlbumPhotoPickerDialog> {
  List<_AlbumInfo> _albumsWithCounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumCounts();
  }

  Future<void> _loadAlbumCounts() async {
    final albumsWithCounts = <_AlbumInfo>[];

    for (var album in widget.albums) {
      final count = await album.assetCountAsync;

      // Only include albums with content
      if (count > 0) {
        // Try to get a valid thumbnail (try first 5 assets if needed)
        AssetEntity? thumbnail;
        final sampleSize = count < 5 ? count : 5;
        final sampleAssets = await album.getAssetListRange(
          start: 0,
          end: sampleSize,
        );

        // Find first valid image/video for thumbnail
        for (var asset in sampleAssets) {
          if (asset.type == AssetType.image || asset.type == AssetType.video) {
            thumbnail = asset;
            break;
          }
        }

        // Only add albums that have at least one valid image/video
        if (thumbnail != null) {
          // For performance, use approximate count instead of loading all assets
          // We assume most assets in the album are valid if we found one
          albumsWithCounts.add(
            _AlbumInfo(
              album: album,
              count: count, // Use total count for speed
              thumbnail: thumbnail,
            ),
          );
        }
      }
    }

    // Sort albums: Recent, Camera, Screenshots first, then others alphabetically
    albumsWithCounts.sort((a, b) {
      final aName = a.album.name.toLowerCase();
      final bName = b.album.name.toLowerCase();

      // Priority order
      final aPriority = _getAlbumPriority(aName);
      final bPriority = _getAlbumPriority(bName);

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      // Same priority, sort alphabetically
      return aName.compareTo(bName);
    });

    if (mounted) {
      setState(() {
        _albumsWithCounts = albumsWithCounts;
        _isLoading = false;
      });
    }
  }

  int _getAlbumPriority(String albumName) {
    // Lower number = higher priority
    if (albumName.contains('recent') || albumName.contains('all')) return 0;
    if (albumName.contains('camera')) return 1;
    if (albumName.contains('screenshot')) return 2;
    return 999; // All others
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width - 32,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Album',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B3E26),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Album grid (like main albums screen)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                      ),
                    )
                  : _albumsWithCounts.isEmpty
                  ? const Center(
                      child: Text(
                        'No albums with photos found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _albumsWithCounts.length,
                      itemBuilder: (context, index) {
                        final albumInfo = _albumsWithCounts[index];
                        return _AlbumCard(
                          albumInfo: albumInfo,
                          onTap: () async {
                            // Navigate to photo picker for this album
                            final selected =
                                await Navigator.push<List<AssetEntity>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => _PhotoSelectionScreen(
                                      album: albumInfo.album,
                                      albumName: albumInfo.album.name,
                                    ),
                                  ),
                                );
                            if (selected != null) {
                              if (!context.mounted) return;
                              Navigator.pop(
                                context,
                                _PickedAlbumSelection(
                                  sourceAlbum: albumInfo.album,
                                  assets: selected,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Album info helper class
class _AlbumInfo {
  final AssetPathEntity album;
  final int count;
  final AssetEntity thumbnail;

  _AlbumInfo({
    required this.album,
    required this.count,
    required this.thumbnail,
  });
}

// Album card widget (similar to FolderCard)
class _AlbumCard extends StatelessWidget {
  final _AlbumInfo albumInfo;
  final VoidCallback onTap;

  const _AlbumCard({required this.albumInfo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: AssetEntityImage(
                  albumInfo.thumbnail,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(300),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumInfo.album.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${albumInfo.count} item${albumInfo.count != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Photo selection screen (shown after selecting an album)
class _PhotoSelectionScreen extends StatefulWidget {
  final AssetPathEntity album;
  final String albumName;

  const _PhotoSelectionScreen({required this.album, required this.albumName});

  @override
  State<_PhotoSelectionScreen> createState() => _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends State<_PhotoSelectionScreen> {
  final Set<String> _selectedIds = {};
  List<AssetEntity> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final count = await widget.album.assetCountAsync;
    final allPhotos = await widget.album.getAssetListRange(
      start: 0,
      end: count,
    );

    // Filter to only images and videos
    final validPhotos = allPhotos.where((asset) {
      return asset.type == AssetType.image || asset.type == AssetType.video;
    }).toList();

    if (mounted) {
      setState(() {
        _photos = validPhotos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        title: Text(
          widget.albumName,
          style: const TextStyle(
            color: Color(0xFF6B3E26),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _photos.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_photos.map((p) => p.id));
                  }
                });
              },
              child: Text(
                _selectedIds.length == _photos.length
                    ? 'Deselect All'
                    : 'Select All',
                style: const TextStyle(color: Color(0xFFF37121)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
              ),
            )
          : _photos.isEmpty
          ? const Center(
              child: Text(
                'No photos in this album',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final isSelected = _selectedIds.contains(photo.id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(photo.id);
                      } else {
                        _selectedIds.add(photo.id);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AssetEntityImage(
                        photo,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(200),
                        fit: BoxFit.cover,
                      ),
                      // Video indicator
                      if (photo.type == AssetType.video)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      // Selection overlay
                      if (isSelected)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Color(0xFFF37121),
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () {
                    final selected = _photos
                        .where((p) => _selectedIds.contains(p.id))
                        .toList();
                    Navigator.pop(context, selected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Add ${_selectedIds.length} Photo${_selectedIds.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
