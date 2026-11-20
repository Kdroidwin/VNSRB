// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:vndb_lite/src/features/vn/domain/others.dart';
import 'package:vndb_lite/src/features/theme/theme_data_provider.dart';
import 'package:vndb_lite/src/util/alt_provider_reader.dart';

abstract class VnDataPhase {}

class VnDataPhase01 implements VnDataPhase {
  const VnDataPhase01({
    required this.id,
    required this.title,
    this.japaneseTitle,
    this.image,
    this.rating,
    this.votecount,
    this.olang,
    this.length,
    this.released,
    this.description,
  });

  final String id;
  final String title;
  final String? japaneseTitle;

  /// The VNDB Japanese title is used only when the user explicitly enables it.
  String get displayTitle {
    try {
      final useJapanese = ref_.read(japaneseTitlesProvider);
      return useJapanese && japaneseTitle != null && japaneseTitle!.isNotEmpty
          ? japaneseTitle!
          : title;
    } catch (_) {
      return title;
    }
  }

  final VnImage? image;
  final double? rating;
  final int? votecount;
  final String? olang;
  final int? length;
  final String? released;
  final String? description;

  VnDataPhase01 copyWith({
    String? id,
    String? title,
    String? japaneseTitle,
    VnImage? image,
    double? rating,
    int? votecount,
    String? olang,
    int? length,
    String? released,
    String? description,
  }) {
    return VnDataPhase01(
      id: id ?? this.id,
      title: title ?? this.title,
      japaneseTitle: japaneseTitle ?? this.japaneseTitle,
      image: image ?? this.image,
      rating: rating ?? this.rating,
      votecount: votecount ?? this.votecount,
      olang: olang ?? this.olang,
      length: length ?? this.length,
      released: released ?? this.released,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'japaneseTitle': japaneseTitle,
      'image': image?.toMap(),
      'rating': rating,
      'votecount': votecount,
      'olang': olang,
      'length': length,
      'released': released,
      'description': description,
    };
  }

  factory VnDataPhase01.fromMap(Map<String, dynamic> data) {
    return VnDataPhase01(
      id: data['id'],
      title: data['title'],
      japaneseTitle:
          _japaneseTitle(data['titles']) ?? data['japaneseTitle'] as String?,
      image:
          data['image'] is Map
              ? VnImage.fromMap(Map<String, dynamic>.from(data['image'] as Map))
              : const VnImage(url: '', thumbnail: ''),
      description: data['description'] ?? '--',
      length: data['length'] ?? 0,
      olang: data['olang'] ?? 'Unknown',
      rating: (data['rating'] ?? 0).toDouble(),
      released: data['released'] ?? 'Unknown',
      votecount: data['votecount'] ?? 0,
    );
  }

  static String? _japaneseTitle(dynamic titles) {
    if (titles is! List) return null;
    for (final entry in titles) {
      if (entry is Map && entry['lang'] == 'ja' && entry['title'] is String) {
        return entry['title'] as String;
      }
    }
    return null;
  }

  String toJson() => json.encode(toMap());

  factory VnDataPhase01.fromJson(String source) =>
      VnDataPhase01.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'VnDataPhase01(id: $id, title: $title, japaneseTitle: $japaneseTitle, image: $image, rating: $rating, votecount: $votecount, olang: $olang, length: $length, released: $released, description: $description)';
  }

  @override
  bool operator ==(covariant VnDataPhase01 other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.title == title &&
        other.japaneseTitle == japaneseTitle &&
        other.image == image &&
        other.rating == rating &&
        other.votecount == votecount &&
        other.olang == olang &&
        other.length == length &&
        other.released == released &&
        other.description == description;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        japaneseTitle.hashCode ^
        image.hashCode ^
        rating.hashCode ^
        votecount.hashCode ^
        olang.hashCode ^
        length.hashCode ^
        released.hashCode ^
        description.hashCode;
  }
}
