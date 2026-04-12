import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:photo_manager/photo_manager.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo_model.dart';
import '../widgets/photo_grid.dart';
import 'album_photos_screen.dart';
import 'settings_screen.dart';
import '../services/search_data_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../widgets/scale_button.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  List<PhotoModel> _allPhotos = [];
  List<PhotoModel> _searchResults = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isInlineSearchActive = false;

  // State variables for categories to prevent FutureBuilder flicker
  List<SearchCategory> _places = [];
  List<SearchCategory> _types = [];

  // Listen to the service
  final SearchDataService _searchService = SearchDataService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Listen for updates
    _searchService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _searchService.removeListener(_onServiceUpdate);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      _updateCategories();
    }
  }

  Future<void> _updateCategories() async {
    final placeGroups = _searchService.placeGroups;
    final typeGroups = _searchService.typeGroups;

    // We build these asynchronously but store them in state to avoid FutureBuilder in build()
    final places = await _buildCategories(placeGroups, 'place');
    final types = await _buildCategories(typeGroups, 'type');

    if (mounted) {
      setState(() {
        _places = places;
        _types = types;
      });
    }
  }

  Future<void> _initializeData() async {
    try {
      await _loadAllPhotos();
      // Service scan is triggered by HomeScreen, but we can trigger it here too just in case
      _searchService.startScan();
      // Initial category build
      _updateCategories();
    } catch (e) {
      debugPrint('Error initializing search data: $e');
    }
  }

  Future<void> _loadAllPhotos() async {
    try {
      final permissionState = await PhotoManager.requestPermissionExtend();
      if (permissionState.isAuth ||
          permissionState == PermissionState.limited) {
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          hasAll: true,
        );

        if (albums.isNotEmpty) {
          final totalCount = await albums.first.assetCountAsync;
          final allAssets = await albums.first.getAssetListRange(
            start: 0,
            end: totalCount,
          );

          final photoAssets = allAssets
              .where((a) => a.type == AssetType.image)
              .toList();

          if (mounted) {
            setState(() {
              _allPhotos = photoAssets
                  .map(
                    (asset) => PhotoModel(
                      id: asset.id,
                      asset: asset,
                      createdDate: asset.createDateTime,
                      isFavorite: false,
                    ),
                  )
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
    }
  }

  void _performSearch(String query) {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _searchQuery = normalizedQuery;
      _isLoading = true;
    });

    final lowerQuery = normalizedQuery.toLowerCase();
    final results = _allPhotos.where((photo) {
      final dateMatch = photo.createdDate.toString().contains(normalizedQuery);
      final nameMatch = (photo.asset.title ?? '').toLowerCase().contains(
        lowerQuery,
      );
      return dateMatch || nameMatch;
    }).toList();

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
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
    _performSearch('');
  }

  // Helper to check file existence for preview
  Future<AssetEntity?> _findValidPreview(List<AssetEntity> group) async {
    for (var asset in group.take(10)) {
      final file = await asset.file;
      if (file != null && await file.exists()) {
        return asset;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
                              onChanged: _performSearch,
                              textInputAction: TextInputAction.search,
                              cursorColor: const Color(0xFF6B3E26),
                              style: const TextStyle(
                                color: Color(0xFF6B3E26),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search by date or name...',
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
                            'Search',
                            style: TextStyle(
                              color: Color(0xFF6B3E26),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (!_isInlineSearchActive) const Spacer(),
                        if (!_isInlineSearchActive)
                          IconButton(
                            icon: const Icon(
                              Icons.search,
                              color: Color(0xFF6B3E26),
                            ),
                            onPressed: _startInlineSearch,
                          ),
                        if (_isInlineSearchActive)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF6B3E26),
                            ),
                            onPressed: _stopInlineSearch,
                          ),
                        if (!_isInlineSearchActive)
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Color(0xFF6B3E26),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110 + MediaQuery.of(context).padding.top + 6,
              ),
            ),
            if (_searchService.isScanning || _searchService.isAnalyzing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _searchService.isAnalyzing
                            ? 'Analyzing photos...'
                            : 'Scanning library...',
                        style: const TextStyle(
                          color: Color(0xFF6B3E26),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (_searchQuery.isEmpty) ...[
              // Places Section
              if (_places.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Places',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B3E26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: _places.length,
                          itemBuilder: (context, index) {
                            final category = _places[index];
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                horizontalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: _CategoryCard(
                                    category: category,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AlbumPhotosScreen(
                                                album: AlbumModel(
                                                  id: 'place_${category.name}',
                                                  name: category.name,
                                                  photoCount: category.count,
                                                ),
                                                preloadedAssets:
                                                    category.assets,
                                              ),
                                        ),
                                      );
                                    },
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
              // Types Section
              if (_types.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Types',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B3E26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: _types.length,
                          itemBuilder: (context, index) {
                            final category = _types[index];
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                horizontalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: _CategoryCard(
                                    category: category,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AlbumPhotosScreen(
                                                album: AlbumModel(
                                                  id: 'type_${category.name}',
                                                  name: category.name,
                                                  photoCount: category.count,
                                                ),
                                                preloadedAssets:
                                                    category.assets,
                                              ),
                                        ),
                                      );
                                    },
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
            ],
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                  ),
                ),
              )
            else if (_searchResults.isEmpty && _searchQuery.isNotEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No photos found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              )
            else if (_searchResults.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                sliver: PhotoGrid(
                  photos: _searchResults,
                  crossAxisCount: 3,
                  asSliver: true,
                  onPhotoDeleted: (photo) {
                    setState(() {
                      _searchResults.removeWhere((p) => p.id == photo.id);
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<List<SearchCategory>> _buildCategories(
    Map<String, List<AssetEntity>> groups,
    String type,
  ) async {
    final categories = <SearchCategory>[];

    // Sort by count
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    for (var key in sortedKeys.take(20)) {
      final group = groups[key]!;
      if (group.isEmpty) continue;

      final preview = await _findValidPreview(group);
      if (preview == null) continue;

      String name = key;
      if (type == 'place') {
        try {
          final parts = key.split(',');
          final lat = double.tryParse(parts[0]) ?? 0.0;
          final lng = double.tryParse(parts[1]) ?? 0.0;

          if (lat != 0 && lng != 0) {
            name = 'Location ($lat, $lng)'; // Default
            List<Placemark> placemarks = await placemarkFromCoordinates(
              lat,
              lng,
            );
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              name =
                  place.locality ??
                  place.subLocality ??
                  place.administrativeArea ??
                  name;
              if (place.subLocality != null &&
                  place.subLocality!.isNotEmpty &&
                  place.locality != null &&
                  place.locality!.isNotEmpty &&
                  place.subLocality != place.locality) {
                name = '${place.subLocality}, ${place.locality}';
              }
            }
          }
        } catch (e) {
          // Keep default name
        }
      }

      // Merge if name exists (mostly for places resolving to same name)
      final existingIndex = categories.indexWhere((c) => c.name == name);
      if (existingIndex != -1) {
        final existing = categories[existingIndex];
        categories[existingIndex] = SearchCategory(
          name: existing.name,
          count: existing.count + group.length,
          preview: existing.preview,
          assets: [...existing.assets, ...group],
          type: type,
        );
      } else {
        categories.add(
          SearchCategory(
            name: name,
            count: group.length,
            preview: preview,
            assets: group,
            type: type,
          ),
        );
      }
    }
    return categories;
  }
}

class SearchCategory {
  final String name;
  final int count;
  final AssetEntity preview;
  final List<AssetEntity> assets;
  final String type; // 'place' or 'type'

  SearchCategory({
    required this.name,
    required this.count,
    required this.preview,
    required this.assets,
    required this.type,
  });
}

class _CategoryCard extends StatelessWidget {
  final SearchCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Single large square photo
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AssetEntityImage(
                      category.preview,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(200),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Category name - centered at bottom
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
