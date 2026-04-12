import 'package:flutter/material.dart';
import 'dart:typed_data' as typed_data;
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_model.dart';
import '../screens/photo_detail_screen.dart';
import '../services/cache_service.dart';
import '../utils/animation_utils.dart';
import 'scale_button.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoModel photo;
  final int index;
  final List<PhotoModel> allPhotos;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(PhotoModel)? onPhotoSelected;
  final VoidCallback? onSelectionModeStarted;
  final Function(PhotoModel)? onPhotoDeleted;
  final VoidCallback? onRefresh;
  final bool isFromTrash;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.index,
    required this.allPhotos,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onPhotoSelected,
    this.onSelectionModeStarted,
    this.onPhotoDeleted,
    this.onRefresh,
    this.isFromTrash = false,
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem>
    with SingleTickerProviderStateMixin {
  final CacheService _cache = CacheService();
  typed_data.Uint8List? _cachedThumbnail;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppAnimations.defaultCurve,
    );
    _loadThumbnail();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Check cache first
    final cached = _cache.getThumbnail(widget.photo.id);
    if (cached != null) {
      setState(() {
        _cachedThumbnail = cached;
        _isLoading = false;
      });
      _fadeController.forward();
      return;
    }

    // Load from asset if not cached
    try {
      final thumbnail = await widget.photo.asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );

      if (thumbnail != null && mounted) {
        await _cache.cacheThumbnail(widget.photo.id, thumbnail);
        setState(() {
          _cachedThumbnail = thumbnail;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: widget.isSelected ? 0.95 : 1.0,
      duration: AppAnimations.fast,
      curve: AppAnimations.smoothCurve,
      child: ScaleButton(
        onTap: () async {
          if (widget.isSelectionMode) {
            widget.onPhotoSelected?.call(widget.photo);
          } else {
            final result = await Navigator.push(
              context,
              AppAnimations.fadeRoute(
                PhotoDetailScreen(
                  photo: widget.photo,
                  allPhotos: widget.allPhotos,
                  initialIndex: widget.index,
                  isFromTrash: widget.isFromTrash,
                ),
              ),
            );
            if (result == 'deleted' && widget.onPhotoDeleted != null) {
              widget.onPhotoDeleted!(widget.photo);
            } else if (result == 'hidden' && widget.onPhotoDeleted != null) {
              widget.onPhotoDeleted!(widget.photo);
            } else if (result == 'restored' && widget.onPhotoDeleted != null) {
              widget.onPhotoDeleted!(widget.photo);
            } else if (result == 'refreshed' && widget.onRefresh != null) {
              widget.onRefresh!();
            }
          }
        },
        onLongPress: () {
          if (!widget.isSelectionMode) {
            widget.onSelectionModeStarted?.call();
            widget.onPhotoSelected?.call(widget.photo);
          }
        },
        child: Hero(
          tag: 'photo_${widget.photo.id}',
          child: Stack(
            children: [
              _buildThumbnail(),
              _buildVideoIndicator(),
              _buildSelectionOverlay(),
              _buildFavoriteIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _cachedThumbnail != null
            ? FadeTransition(
                opacity: _fadeAnimation,
                child: Image.memory(
                  _cachedThumbnail!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
              )
            : AppAnimations.shimmerLoading(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.circular(12),
              ),
      ),
    );
  }

  Widget _buildVideoIndicator() {
    if (widget.photo.asset.type != AssetType.video) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 8,
      right: 8,
      child: AnimatedOpacity(
        opacity: _cachedThumbnail != null ? 1.0 : 0.0,
        duration: AppAnimations.medium,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Colors.white, size: 16),
              if (widget.photo.asset.videoDuration.inSeconds > 0) ...[
                const SizedBox(width: 4),
                Text(
                  _formatDuration(widget.photo.asset.videoDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay() {
    if (!widget.isSelectionMode) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.defaultCurve,
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: widget.isSelected
              ? Border.all(color: const Color(0xFFF37121), width: 3)
              : null,
        ),
        child: widget.isSelected
            ? Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: AppAnimations.medium,
                      curve: AppAnimations.bounceCurve,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Color(0xFFF37121),
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildFavoriteIndicator() {
    if (widget.isSelectionMode || !widget.photo.isFavorite) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      right: 8,
      child: AnimatedOpacity(
        opacity: _cachedThumbnail != null ? 1.0 : 0.0,
        duration: AppAnimations.medium,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite, color: Color(0xFFF37121), size: 16),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
