import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/photo_model.dart';
import 'photo_grid_item.dart';
import 'trash_photo_grid_item.dart';

class PhotoGrid extends StatefulWidget {
  final List<PhotoModel> photos;
  final Function(PhotoModel)? onPhotoDeleted;
  final int crossAxisCount;
  final bool asSliver;
  final bool isSelectionMode;
  final Set<String> selectedPhotoIds;
  final Function(PhotoModel)? onPhotoSelected;
  final VoidCallback? onSelectionModeStarted;
  final bool isFromTrash;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onRefresh;

  const PhotoGrid({
    super.key,
    required this.photos,
    this.onPhotoDeleted,
    this.crossAxisCount = 3,
    this.asSliver = false,
    this.isSelectionMode = false,
    this.selectedPhotoIds = const {},
    this.onPhotoSelected,
    this.onSelectionModeStarted,
    this.isFromTrash = false,
    this.padding,
    this.onRefresh,
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.photos.isEmpty) {
      final emptyWidget = const Center(
        child: Text(
          'No photos found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );

      return widget.asSliver
          ? SliverToBoxAdapter(child: SizedBox(height: 200, child: emptyWidget))
          : emptyWidget;
    }

    if (widget.asSliver) {
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => widget.isFromTrash
              ? TrashPhotoGridItem(
                  photo: widget.photos[index],
                  index: index,
                  allPhotos: widget.photos,
                  isSelectionMode: widget.isSelectionMode,
                  isSelected: widget.selectedPhotoIds.contains(
                    widget.photos[index].id,
                  ),
                  onPhotoSelected: widget.onPhotoSelected,
                  onSelectionModeStarted: widget.onSelectionModeStarted,
                  onPhotoDeleted: widget.onPhotoDeleted,
                  onRefresh: widget.onRefresh,
                )
              : PhotoGridItem(
                  photo: widget.photos[index],
                  index: index,
                  allPhotos: widget.photos,
                  isSelectionMode: widget.isSelectionMode,
                  isSelected: widget.selectedPhotoIds.contains(
                    widget.photos[index].id,
                  ),
                  onPhotoSelected: widget.onPhotoSelected,
                  onSelectionModeStarted: widget.onSelectionModeStarted,
                  onPhotoDeleted: widget.onPhotoDeleted,
                  onRefresh: widget.onRefresh,
                  isFromTrash: widget.isFromTrash,
                ),
          childCount: widget.photos.length,
        ),
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        padding: widget.padding ?? const EdgeInsets.all(12),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) => AnimationConfiguration.staggeredGrid(
          position: index,
          duration: const Duration(milliseconds: 375),
          columnCount: widget.crossAxisCount,
          child: ScaleAnimation(
            child: FadeInAnimation(
              child: widget.isFromTrash
                  ? TrashPhotoGridItem(
                      photo: widget.photos[index],
                      index: index,
                      allPhotos: widget.photos,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: widget.selectedPhotoIds.contains(
                        widget.photos[index].id,
                      ),
                      onPhotoSelected: widget.onPhotoSelected,
                      onSelectionModeStarted: widget.onSelectionModeStarted,
                      onPhotoDeleted: widget.onPhotoDeleted,
                      onRefresh: widget.onRefresh,
                    )
                  : PhotoGridItem(
                      photo: widget.photos[index],
                      index: index,
                      allPhotos: widget.photos,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: widget.selectedPhotoIds.contains(
                        widget.photos[index].id,
                      ),
                      onPhotoSelected: widget.onPhotoSelected,
                      onSelectionModeStarted: widget.onSelectionModeStarted,
                      onPhotoDeleted: widget.onPhotoDeleted,
                      onRefresh: widget.onRefresh,
                      isFromTrash: widget.isFromTrash,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
