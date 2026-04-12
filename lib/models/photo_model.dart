import 'package:photo_manager/photo_manager.dart';

class PhotoModel {
  final String id;
  final AssetEntity asset;
  final DateTime createdDate;
  bool isFavorite;

  PhotoModel({
    required this.id,
    required this.asset,
    required this.createdDate,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'isFavorite': isFavorite};
  }

  factory PhotoModel.fromJson(Map<String, dynamic> json, AssetEntity asset) {
    return PhotoModel(
      id: json['id'],
      asset: asset,
      createdDate: asset.createDateTime,
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

class AlbumModel {
  final String id;
  final String name;
  final int photoCount;
  final AssetPathEntity? pathEntity;
  AssetEntity? thumbnailAsset;
  List<AssetEntity>? thumbnailAssets; // For 3-photo stack

  AlbumModel({
    required this.id,
    required this.name,
    required this.photoCount,
    this.pathEntity,
    this.thumbnailAsset,
    this.thumbnailAssets,
  });
}
