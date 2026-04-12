import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:ui';
import '../models/photo_model.dart';
import '../widgets/photo_grid.dart';
import '../services/trash_service.dart';
import '../widgets/custom_notification.dart';
import '../services/photo_service.dart';

class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen>
    with WidgetsBindingObserver {
  final TrashService _trashService = TrashService();
  List<PhotoModel> _photos = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedPhotoIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTrashedPhotos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTrashedPhotos();
    }
  }

  Future<void> _loadTrashedPhotos() async {
    setState(() => _isLoading = true);
    try {
      final trashedIds = await _trashService.getTrashedPhotoIds();
      if (trashedIds.isEmpty) {
        setState(() {
          _photos = [];
          _isLoading = false;
        });
        return;
      }

      // We need to fetch assets by ID.
      // PhotoManager doesn't have a direct "getAssetsByIds" that returns a list easily without filtering.
      // But we can use getAssetPathList and then filter? No, that's inefficient.
      // We can try to find them one by one or use a custom filter?
      // Actually, PhotoManager has `AssetEntity.fromId`.

      List<PhotoModel> loadedPhotos = [];
      for (String id in trashedIds) {
        final asset = await AssetEntity.fromId(id);
        if (asset != null) {
          loadedPhotos.add(
            PhotoModel(
              id: asset.id,
              asset: asset,
              createdDate: asset.createDateTime,
              isFavorite:
                  false, // Favorite status might be lost or irrelevant in trash
            ),
          );
        } else {
          // Asset not found on device, maybe remove from trash?
          _trashService.deletePermanently(id);
        }
      }

      if (mounted) {
        setState(() {
          _photos = loadedPhotos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          message: 'Error loading trash: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotoIds.clear();
      }
    });
  }

  void _onPhotoSelected(PhotoModel photo) {
    setState(() {
      if (_selectedPhotoIds.contains(photo.id)) {
        _selectedPhotoIds.remove(photo.id);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotoIds.add(photo.id);
        _isSelectionMode = true;
      }
    });
  }

  void _onPhotoRemoved(PhotoModel photo) {
    if (!mounted) return;
    setState(() {
      _photos.removeWhere((p) => p.id == photo.id);
      _selectedPhotoIds.remove(photo.id);
      if (_selectedPhotoIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _restoreSelectedPhotos() async {
    try {
      for (String id in _selectedPhotoIds) {
        await _trashService.restoreFromTrash(id);
      }

      setState(() {
        _photos.removeWhere((p) => _selectedPhotoIds.contains(p.id));
        _isSelectionMode = false;
        _selectedPhotoIds.clear();
      });

      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Photos restored',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Failed to restore photos',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _deleteSelectedPhotosPermanently() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: const Text(
          'These photos will be removed from your device. This action cannot be undone.',
        ),
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
        // Use PhotoService to delete (uses SAF to avoid prompt if possible)
        final PhotoService photoService = PhotoService();
        final photosToDelete = _photos
            .where((p) => _selectedPhotoIds.contains(p.id))
            .toList();

        for (var photo in photosToDelete) {
          await photoService.deletePermanently(photo);
        }

        setState(() {
          _photos.removeWhere((p) => _selectedPhotoIds.contains(p.id));
          _isSelectionMode = false;
          _selectedPhotoIds.clear();
        });

        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Photos permanently deleted',
            type: NotificationType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Failed to delete photos: $e',
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
      appBar: PreferredSize(
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
                            _isSelectionMode
                                ? '${_selectedPhotoIds.length} Selected'
                                : 'Recently Deleted',
                            style: const TextStyle(
                              color: Color(0xFF6B3E26),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isSelectionMode) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.restore,
                              color: Color(0xFF6B3E26),
                            ),
                            onPressed: _restoreSelectedPhotos,
                            tooltip: 'Restore',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                            onPressed: _deleteSelectedPhotosPermanently,
                            tooltip: 'Delete Permanently',
                          ),
                        ] else
                          IconButton(
                            icon: const Icon(
                              Icons.checklist,
                              color: Color(0xFF6B3E26),
                            ),
                            onPressed: _toggleSelectionMode,
                            tooltip: 'Select',
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
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No recently deleted items',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : PhotoGrid(
              photos: _photos,
              onPhotoDeleted: _onPhotoRemoved,
              selectedPhotoIds: _selectedPhotoIds,
              onPhotoSelected: _onPhotoSelected,
              onSelectionModeStarted: () => setState(() {
                _isSelectionMode = true;
              }),
              isFromTrash: true,
              padding: EdgeInsets.only(
                top: 110 + MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 2,
                bottom: 20,
              ),
            ),
    );
  }
}
