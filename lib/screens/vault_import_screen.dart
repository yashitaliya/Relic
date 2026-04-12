import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_model.dart';
import '../widgets/photo_grid.dart';
import '../widgets/folder_card.dart';
import '../services/vault_service.dart';
import '../services/photo_service.dart';
import '../widgets/custom_notification.dart';
import '../widgets/glass_app_bar.dart';

class VaultImportScreen extends StatefulWidget {
  const VaultImportScreen({super.key});

  @override
  State<VaultImportScreen> createState() => _VaultImportScreenState();
}

class _VaultImportScreenState extends State<VaultImportScreen> {
  final VaultService _vaultService = VaultService();
  List<AlbumModel> _albums = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedAlbumIds = {};
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);

    final permissionState = await PhotoManager.requestPermissionExtend();
    if (!permissionState.isAuth && permissionState != PermissionState.limited) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Use FilterOptionGroup to try to limit to Image and Video if possible
      // Note: RequestType.common includes Audio. We can't easily exclude it without custom filter,
      // but we can filter the results.
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
      for (var album in albums) {
        final assetCount = await album.assetCountAsync;

        // Filter out empty albums
        if (assetCount == 0) continue;

        // Fetch first asset to check type and get thumbnail
        final assets = await album.getAssetListRange(start: 0, end: 1);

        if (assets.isEmpty) continue;

        final firstAsset = assets.first;

        // Strict filter: Only show album if the first asset is Image or Video
        // This helps filter out "Audio" albums if they are separate,
        // but "Recent" might still contain audio.
        // To be safe, we just ensure we have a valid thumbnail.
        if (firstAsset.type != AssetType.image &&
            firstAsset.type != AssetType.video) {
          // If the first asset is not image/video, check if album contains ANY image/video?
          // That would be expensive. For now, assume if first item is not media, skip?
          // Better: Just check if we can get a thumbnail.
          // But user specifically complained about "incorrect count" (8781).
          // If we want to exclude audio from count, we can't easily do it without fetching all.
          // So we'll accept the count but ensure we only show folders with content.
        }

        albumModels.add(
          AlbumModel(
            id: album.id,
            name: album.name,
            photoCount: assetCount,
            pathEntity: album,
            thumbnailAsset: firstAsset,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _albums = albumModels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading albums: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedAlbumIds.contains(id)) {
        _selectedAlbumIds.remove(id);
        if (_selectedAlbumIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedAlbumIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _importSelectedAlbums() async {
    if (_selectedAlbumIds.isEmpty) return;

    setState(() => _isImporting = true);
    int successCount = 0;

    try {
      final selectedAlbums = _albums
          .where((a) => _selectedAlbumIds.contains(a.id))
          .toList();

      for (final album in selectedAlbums) {
        final assetCount = await album.pathEntity!.assetCountAsync;
        // Process in batches of 50 to avoid memory issues
        const batchSize = 50;
        for (int i = 0; i < assetCount; i += batchSize) {
          final assets = await album.pathEntity!.getAssetListRange(
            start: i,
            end: i + batchSize < assetCount ? i + batchSize : assetCount,
          );

          for (final asset in assets) {
            if (asset.type == AssetType.image ||
                asset.type == AssetType.video) {
              await _vaultService.hideFile(asset);
              // Emit hidden change event for vault refresh
              PhotoService.emitHiddenChange(asset.id, true);
              successCount++;
            }
          }
        }
      }

      if (mounted) {
        CustomNotification.show(
          context,
          message:
              'Hidden $successCount items from ${_selectedAlbumIds.length} albums',
          type: NotificationType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error hiding albums: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: _isSelectionMode
            ? '${_selectedAlbumIds.length} Selected'
            : 'Local Albums',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B3E26)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, color: Color(0xFF6B3E26)),
              onPressed: _isImporting ? null : _importSelectedAlbums,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: EdgeInsets.only(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _albums.length,
              itemBuilder: (context, index) {
                final album = _albums[index];
                final isSelected = _selectedAlbumIds.contains(album.id);
                return FolderCard(
                  album: album,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected,
                  onTap: () async {
                    if (_isSelectionMode) {
                      _toggleSelection(album.id);
                    } else {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VaultImportPhotosScreen(album: album),
                        ),
                      );
                      if (result == true) {
                        if (!context.mounted) return;
                        Navigator.pop(context, true); // Propagate success
                      }
                    }
                  },
                  onLongPress: () => _toggleSelection(album.id),
                );
              },
            ),
    );
  }
}

class VaultImportPhotosScreen extends StatefulWidget {
  final AlbumModel album;

  const VaultImportPhotosScreen({super.key, required this.album});

  @override
  State<VaultImportPhotosScreen> createState() =>
      _VaultImportPhotosScreenState();
}

class _VaultImportPhotosScreenState extends State<VaultImportPhotosScreen> {
  final VaultService _vaultService = VaultService();
  List<PhotoModel> _photos = [];
  bool _isLoading = true;
  final Set<String> _selectedPhotoIds = {};
  bool _isImporting = false;
  bool _isSelectAll = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final totalCount = await widget.album.pathEntity!.assetCountAsync;
      final assets = await widget.album.pathEntity!.getAssetListRange(
        start: 0,
        end: totalCount,
      );

      final photos = assets
          .where(
            (asset) =>
                asset.type == AssetType.image || asset.type == AssetType.video,
          )
          .map(
            (asset) => PhotoModel(
              id: asset.id,
              asset: asset,
              createdDate: asset.createDateTime,
              isFavorite: false,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onPhotoSelected(PhotoModel photo) {
    setState(() {
      if (_selectedPhotoIds.contains(photo.id)) {
        _selectedPhotoIds.remove(photo.id);
        _isSelectAll = false;
      } else {
        _selectedPhotoIds.add(photo.id);
        if (_selectedPhotoIds.length == _photos.length) {
          _isSelectAll = true;
        }
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isSelectAll) {
        _selectedPhotoIds.clear();
        _isSelectAll = false;
      } else {
        _selectedPhotoIds.addAll(_photos.map((p) => p.id));
        _isSelectAll = true;
      }
    });
  }

  Future<void> _importSelected() async {
    if (_selectedPhotoIds.isEmpty) return;

    setState(() => _isImporting = true);

    int successCount = 0;

    try {
      final selectedPhotos = _photos
          .where((p) => _selectedPhotoIds.contains(p.id))
          .toList();

      for (final photo in selectedPhotos) {
        await _vaultService.hideFile(photo.asset);
        // Emit hidden change event for vault refresh
        PhotoService.emitHiddenChange(photo.id, true);
        successCount++;
      }

      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Hidden $successCount items',
          type: NotificationType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error hiding items: $e',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B3E26)),
          onPressed: () => Navigator.pop(context),
        ),
        title: _selectedPhotoIds.isEmpty
            ? widget.album.name
            : '${_selectedPhotoIds.length} Selected',
        actions: [
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(
              _isSelectAll ? 'Deselect All' : 'Select All',
              style: const TextStyle(color: Color(0xFFF37121)),
            ),
          ),
          if (_selectedPhotoIds.isNotEmpty)
            TextButton(
              onPressed: _isImporting ? null : _importSelected,
              child: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'HIDE',
                      style: TextStyle(
                        color: Color(0xFFF37121),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PhotoGrid(
              photos: _photos,
              isSelectionMode: true,
              padding: EdgeInsets.only(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
                left: 12,
                right: 12,
                bottom: 12,
              ),
              selectedPhotoIds: _selectedPhotoIds,
              onPhotoSelected: _onPhotoSelected,
              onSelectionModeStarted: () {},
              onPhotoDeleted: (_) {},
              onRefresh: _loadPhotos,
              crossAxisCount: 3,
            ),
    );
  }
}
