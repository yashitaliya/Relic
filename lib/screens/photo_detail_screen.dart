import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/custom_notification.dart';
import '../widgets/styled_dialog.dart';
import 'video_player_screen.dart';
import '../widgets/scale_button.dart';

class PhotoDetailScreen extends StatefulWidget {
  final PhotoModel photo;
  final List<PhotoModel>? allPhotos;
  final int? initialIndex;
  final bool isFromTrash;

  const PhotoDetailScreen({
    super.key,
    required this.photo,
    this.allPhotos,
    this.initialIndex,
    this.isFromTrash = false,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen>
    with SingleTickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  late PageController _pageController;
  late int _currentIndex;
  late bool _isFavorite;
  late AnimationController _animationController;
  bool _showControls = true;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    _isFavorite = widget.photo.isFavorite;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  void _onScaleChanged(bool isZoomed) {
    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  PhotoModel get _currentPhoto => widget.allPhotos != null
      ? widget.allPhotos![_currentIndex]
      : widget.photo;

  void _toggleControls() {
    if (_isZoomed) return; // Don't toggle controls while zooming
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _formatVideoDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _toggleFavorite() async {
    await _photoService.toggleFavorite(_currentPhoto);
    setState(() => _isFavorite = _currentPhoto.isFavorite);
    if (mounted) {
      CustomNotification.show(
        context,
        message: _isFavorite ? 'Added to favorites' : 'Removed from favorites',
        type: NotificationType.success,
      );
    }
  }

  Future<void> _sharePhoto() async =>
      await _photoService.sharePhoto(_currentPhoto);

  Future<void> _showPhotoInfo() async {
    final info = await _photoService.getPhotoInfo(_currentPhoto);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B3E26),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...info.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePhoto() async {
    final confirmed = await StyledDialog.showConfirmation(
      context: context,
      title: 'Delete Photo',
      message: 'Are you sure you want to delete this photo?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true) {
      if (!mounted) return;
      final success = await _photoService.deletePhoto(_currentPhoto);
      if (mounted) {
        if (success) {
          Navigator.pop(context, 'deleted');
          CustomNotification.show(
            context,
            message: 'Photo deleted successfully',
            type: NotificationType.success,
          );
        } else {
          CustomNotification.show(
            context,
            message: 'Failed to delete photo',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _editPhoto() async {
    try {
      // Get file from current photo
      final file = await _currentPhoto.asset.file;
      if (file == null) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Failed to load image',
            type: NotificationType.error,
          );
        }
        return;
      }

      // Read image bytes
      final bytes = await file.readAsBytes();

      // Open pro_image_editor
      if (!mounted) return;
      final editedBytes = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.memory(
            bytes,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                Navigator.pop(context, bytes);
              },
            ),
          ),
        ),
      );

      if (editedBytes != null && mounted) {
        // Save edited image
        final success = await _photoService.saveEditedPhoto(
          editedBytes,
          originalPhoto: _currentPhoto,
        );

        if (!mounted) return;

        if (success) {
          CustomNotification.show(
            context,
            message: 'Image saved successfully',
            type: NotificationType.success,
          );
          // Pop back with refresh signal
          Navigator.pop(context, 'refreshed');
        } else {
          CustomNotification.show(
            context,
            message: 'Failed to save image',
            type: NotificationType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Error editing photo: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _restorePhoto() async {
    final success = await _photoService.restoreFromTrash(_currentPhoto);
    if (mounted) {
      if (success) {
        Navigator.pop(context, 'restored');
        CustomNotification.show(
          context,
          message: 'Photo restored successfully',
          type: NotificationType.success,
        );
      } else {
        CustomNotification.show(
          context,
          message: 'Failed to restore photo',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _deletePermanently() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: const Text(
          'This photo will be removed from your device. This action cannot be undone.',
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
      if (!mounted) return;
      final success = await _photoService.deletePermanently(_currentPhoto);
      if (mounted) {
        if (success) {
          Navigator.pop(context, 'deleted');
          CustomNotification.show(
            context,
            message: 'Photo permanently deleted',
            type: NotificationType.success,
          );
        } else {
          CustomNotification.show(
            context,
            message: 'Failed to delete photo',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleControls,
            child: widget.allPhotos != null
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: widget.allPhotos!.length,
                    physics: _isZoomed
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    pageSnapping: true,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _isFavorite = _currentPhoto.isFavorite;
                      });
                    },
                    itemBuilder: (context, index) {
                      final currentPhoto = widget.allPhotos![index];

                      // Wrap in padding for spacing
                      Widget photoWidget;

                      // Check if current item is a video
                      if (currentPhoto.asset.type == AssetType.video) {
                        // ... (keep video logic)
                        photoWidget = FutureBuilder<Uint8List?>(
                          future: currentPhoto.asset.thumbnailDataWithSize(
                            const ThumbnailSize(400, 400),
                          ),
                          builder: (context, snapshot) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Video thumbnail background
                                if (snapshot.hasData && snapshot.data != null)
                                  Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.contain,
                                  )
                                else
                                  Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          Color(0xFFF37121),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Play button overlay - only this opens video
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      // Extract all videos from the list
                                      final allVideos = widget.allPhotos!
                                          .where(
                                            (p) =>
                                                p.asset.type == AssetType.video,
                                          )
                                          .map((p) => p.asset)
                                          .toList();
                                      final videoIndex = allVideos.indexOf(
                                        currentPhoto.asset,
                                      );

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              VideoPlayerScreen(
                                                video: currentPhoto.asset,
                                                allVideos: allVideos,
                                                initialIndex: videoIndex >= 0
                                                    ? videoIndex
                                                    : 0,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        size: 64,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                // Duration badge
                                if (currentPhoto.asset.videoDuration.inSeconds >
                                    0)
                                  Positioned(
                                    bottom: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatVideoDuration(
                                          currentPhoto.asset.videoDuration,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      } else {
                        photoWidget = PhotoItem(
                          photo: currentPhoto,
                          tag: 'photo_${currentPhoto.id}',
                          onTap: _toggleControls,
                          onScaleChanged: _onScaleChanged,
                        );
                      }

                      // Add padding for spacing between photos
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: photoWidget,
                      );
                    },
                  )
                : PhotoItem(
                    photo: widget.photo,
                    tag: 'photo_${widget.photo.id}',
                    onTap: _toggleControls,
                    onScaleChanged: _onScaleChanged,
                  ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Opacity(
                  opacity: _animationController.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      if (widget.allPhotos != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.allPhotos!.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                bottom: 40 + MediaQuery.of(context).padding.bottom,
                left: 24,
                right: 24,
                child: Opacity(
                  opacity: _animationController.value,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2C2C2C,
                            ).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: widget.isFromTrash
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.restore_from_trash,
                                        color: Colors.blue[300],
                                        onTap: _restorePhoto,
                                      ),
                                      const SizedBox(width: 24),
                                      _buildActionButton(
                                        icon: Icons.delete_forever,
                                        color: Colors.red[300],
                                        onTap: _deletePermanently,
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton(
                                        icon: _isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: _isFavorite
                                            ? const Color(0xFFF37121)
                                            : Colors.white,
                                        onTap: _toggleFavorite,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildActionButton(
                                        icon: Icons.share,
                                        onTap: _sharePhoto,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildActionButton(
                                        icon: Icons.edit,
                                        onTap: _editPhoto,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildActionButton(
                                        icon: Icons.info_outline,
                                        onTap: _showPhotoInfo,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildActionButton(
                                        icon: Icons.delete_outline,
                                        color: Colors.red[300],
                                        onTap: _deletePhoto,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color ?? Colors.white, size: 28),
      ),
    );
  }
}

class PhotoItem extends StatefulWidget {
  final PhotoModel photo;
  final String tag;
  final Function(bool)? onScaleChanged;
  final VoidCallback? onTap;

  const PhotoItem({
    super.key,
    required this.photo,
    required this.tag,
    this.onScaleChanged,
    this.onTap,
  });

  @override
  State<PhotoItem> createState() => _PhotoItemState();
}

class _PhotoItemState extends State<PhotoItem>
    with AutomaticKeepAliveClientMixin {
  Future<File?>? _fileFuture;
  late PhotoViewController _photoViewController;

  @override
  void initState() {
    super.initState();
    _fileFuture = widget.photo.asset.file;
    _photoViewController = PhotoViewController()
      ..outputStateStream.listen((PhotoViewControllerValue value) {
        // Notify parent when scale changes
        final isZoomed = value.scale != null && value.scale! > 1.0;
        widget.onScaleChanged?.call(isZoomed);
      });
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Hero(
            tag: widget.tag,
            child: PhotoView(
              controller: _photoViewController,
              imageProvider: FileImage(snapshot.data!),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              onTapUp: (context, details, controllerValue) =>
                  widget.onTap?.call(),
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                ),
              ),
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
          ),
        );
      },
    );
  }
}
