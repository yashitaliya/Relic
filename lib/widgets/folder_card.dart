import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo_model.dart';
import 'scale_button.dart';

class FolderCard extends StatelessWidget {
  final AlbumModel album;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final int gridSize;

  const FolderCard({
    super.key,
    required this.album,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.gridSize = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = gridSize > 2;
    final titleSize = isCompact ? 12.0 : 14.0;
    final subtitleSize = isCompact ? 10.0 : 12.0;
    final cardPadding = isCompact ? 8.0 : 10.0;

    return ScaleButton(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final photoWidth = constraints.maxWidth;
                  const stackOffset = 8.0;
                  const heightReduction = 10.0;
                  final mainPhotoSize = photoWidth - stackOffset * 2;
                  // Ensure heights are never negative
                  final backHeight = (mainPhotoSize - heightReduction * 2).clamp(10.0, double.infinity);
                  final middleHeight = (mainPhotoSize - heightReduction).clamp(10.0, double.infinity);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Back Layer (3rd photo)
                      if (album.thumbnailAssets != null &&
                          album.thumbnailAssets!.length > 2 &&
                          mainPhotoSize > 30)
                        Positioned(
                          left: stackOffset * 2,
                          top: 0,
                          child: Container(
                            width: mainPhotoSize,
                            height: backHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 3,
                                  offset: const Offset(1, 0),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AssetEntityImage(
                                album.thumbnailAssets![2],
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(250),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      // Middle Layer (2nd photo)
                      if (album.thumbnailAssets != null &&
                          album.thumbnailAssets!.length > 1 &&
                          mainPhotoSize > 20)
                        Positioned(
                          left: stackOffset,
                          top: 0,
                          child: Container(
                            width: mainPhotoSize,
                            height: middleHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 3,
                                  offset: const Offset(1, 0),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: AssetEntityImage(
                                album.thumbnailAssets![1],
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(250),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      // Front Layer (Main photo)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: mainPhotoSize.clamp(10.0, double.infinity),
                          height: mainPhotoSize.clamp(10.0, double.infinity),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildThumbnail(),
                          ),
                        ),
                      ),
                      // Selection indicator
                      if (isSelectionMode)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? const Color(0xFFF37121)
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D4037),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '(${album.photoCount} Photos)',
              style: TextStyle(
                fontSize: subtitleSize,
                color: const Color(0xFF8D6E63),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (album.thumbnailAsset == null) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Icon(Icons.photo_library, size: 36, color: Colors.grey),
        ),
      );
    }

    return AssetEntityImage(
      album.thumbnailAsset!,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize.square(800),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[100],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      },
    );
  }
}
