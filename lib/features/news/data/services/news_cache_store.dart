import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/club_news_post.dart';
import '../../domain/models/instagram_post.dart';

class CachedNewsContent {
  const CachedNewsContent({
    required this.clubPosts,
    required this.instagramPosts,
  });

  final List<ClubNewsPost> clubPosts;
  final List<InstagramPost> instagramPosts;
}

class NewsCacheStore {
  NewsCacheStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'news.content.v1';
  final SharedPreferencesAsync _preferences;

  Future<void> save({
    required List<ClubNewsPost> clubPosts,
    required List<InstagramPost> instagramPosts,
  }) => _preferences.setString(
    _key,
    jsonEncode({
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'club_posts': clubPosts.map((post) => post.toJson()).toList(),
      'instagram_posts': instagramPosts.map((post) => post.toJson()).toList(),
    }),
  );

  Future<CachedNewsContent?> read() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final clubPosts = (json['club_posts'] as List<dynamic>)
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return ClubNewsPost.fromJson(
              map,
              imageUrl: map['image_url'] as String?,
            );
          })
          .toList(growable: false);
      final instagramPosts = (json['instagram_posts'] as List<dynamic>)
          .map(
            (item) =>
                InstagramPost.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
      return CachedNewsContent(
        clubPosts: clubPosts,
        instagramPosts: instagramPosts,
      );
    } on Object {
      return null;
    }
  }
}
