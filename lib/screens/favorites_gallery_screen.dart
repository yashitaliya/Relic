import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:ui';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import 'dart:async';
import '../widgets/photo_grid.dart';
import '../widgets/custom_notification.dart';
import '../services/settings_service.dart';
import '../utils/animation_utils.dart';

class FavoritesGalleryScreen extends StatefulWidget {
  const FavoritesGalleryScreen({super.key});

  @override
  State<FavoritesGalleryScreen> createState() => _FavoritesGalleryScreenState();
}

class _FavoritesGalleryScreenState extends State<FavoritesGalleryScreen>
    with WidgetsBindingObserver {
  final PhotoService _photoService = PhotoService();
  final SettingsService _settingsService = SettingsService();
  List<PhotoModel> _favoritePhotos = [];
  bool _isLoading = true;
  int _gridSize = 3;
  StreamSubscription<FavoriteChange>? _favoriteSubscription;
  StreamSubscription<void>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsSubscription = SettingsService.changes.listen((_) {
      _loadSettings();
    });
    _loadSettings();
    _loadFavorites();
    _favoriteSubscription = PhotoService.onFavoriteChanged.listen(
      _onFavoriteChanged,
    );
  }

  void _onFavoriteChanged(FavoriteChange event) {
    if (!mounted) return;
    if (event.isFavorite) {
      // If added to favorites, we should reload or add it.
      // Since we don't have the full asset here easily without querying,
      // and we want to keep order, reloading is safest for now.
      _loadFavorites();
    } else {
      // If removed, we can just remove it from the list.
      final index = _favoritePhotos.indexWhere((p) => p.id == event.id);
      if (index != -1) {
        setState(() {
          _favoritePhotos.removeAt(index);
        });
      }
    }
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
    _settingsSubscription?.cancel();
    _favoriteSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      // In a real app, we'd query a database for favorite IDs.
      // Since we don't have a persistent DB for favorites yet (using SharedPreferences in PhotoService),
      // we need to iterate through all photos and check if they are favorites.
      // This is inefficient for large libraries but works for this demo.

      // Optimization: PhotoService could maintain a list of favorite IDs.
      // Let's assume PhotoService has a method to get all favorite IDs,
      // then we fetch those specific assets.

      // For now, let's just load recent photos and filter.
      // Ideally, we should have `getFavoritePhotos` in PhotoService.

      // Let's implement a simple version: Load all photos and filter.
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      if (albums.isNotEmpty) {
        final recentAlbum = albums.first;
        final assetCount = await recentAlbum.assetCountAsync;
        final assets = await recentAlbum.getAssetListRange(
          start: 0,
          end: assetCount,
        ); // Warning: Loading all assets might be slow

        List<PhotoModel> favs = [];
        for (var asset in assets) {
          final isFav = await _photoService.isFavorite(asset.id);
          if (isFav) {
            favs.add(
              PhotoModel(
                id: asset.id,
                asset: asset,
                createdDate: asset.createDateTime,
                isFavorite: true,
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _favoritePhotos = favs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          message: 'Error loading favorites',
          type: NotificationType.error,
        );
      }
    }
  }

  void _onPhotoDeleted(PhotoModel photo) {
    setState(() {
      _favoritePhotos.remove(photo);
    });
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
                        const Text(
                          'Favorites',
                          style: TextStyle(
                            color: Color(0xFF6B3E26),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
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
          : _favoritePhotos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SmoothRefreshIndicator(
              onRefresh: _loadFavorites,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: 110 + MediaQuery.of(context).padding.top + 16,
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    sliver: PhotoGrid(
                      photos: _favoritePhotos,
                      crossAxisCount: _gridSize,
                      onPhotoDeleted: _onPhotoDeleted,
                      onRefresh: _loadFavorites,
                      asSliver: true,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
