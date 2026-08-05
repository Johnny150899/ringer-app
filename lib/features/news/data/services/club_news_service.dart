import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/club_news_post.dart';

class ClubNewsService {
  const ClubNewsService(this._client);

  final SupabaseClient _client;

  Future<List<ClubNewsPost>> loadPosts() async {
    final rows = await _client
        .from('club_news_posts')
        .select('id, title, body, image_path, created_by, published_at')
        .order('published_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows)
        .map((row) {
          final path = row['image_path'] as String?;
          return ClubNewsPost.fromJson(
            row,
            imageUrl: path == null
                ? null
                : _client.storage.from('news-images').getPublicUrl(path),
          );
        })
        .toList(growable: false);
  }

  Future<void> createPost({
    required String title,
    required String body,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final imagePath = imageBytes == null
        ? null
        : await _uploadImage(userId, imageBytes, imageExtension ?? 'jpg');
    try {
      await _client.from('club_news_posts').insert({
        'title': title.trim(),
        'body': body.trim(),
        'image_path': imagePath,
        'created_by': userId,
      });
    } catch (_) {
      if (imagePath != null) {
        await _client.storage.from('news-images').remove([imagePath]);
      }
      rethrow;
    }
  }

  Future<void> updatePost({
    required ClubNewsPost post,
    required String title,
    required String body,
    Uint8List? newImageBytes,
    String? imageExtension,
    bool removeImage = false,
  }) async {
    var imagePath = removeImage ? null : post.imagePath;
    if (newImageBytes != null) {
      imagePath = await _uploadImage(
        _client.auth.currentUser!.id,
        newImageBytes,
        imageExtension ?? 'jpg',
      );
    }
    await _client
        .from('club_news_posts')
        .update({
          'title': title.trim(),
          'body': body.trim(),
          'image_path': imagePath,
        })
        .eq('id', post.id);
    if ((removeImage || newImageBytes != null) && post.imagePath != null) {
      await _client.storage.from('news-images').remove([post.imagePath!]);
    }
  }

  Future<void> deletePost(ClubNewsPost post) async {
    await _client.from('club_news_posts').delete().eq('id', post.id);
    if (post.imagePath != null) {
      await _client.storage.from('news-images').remove([post.imagePath!]);
    }
  }

  Future<String> _uploadImage(
    String userId,
    Uint8List bytes,
    String extension,
  ) async {
    final normalized = extension.toLowerCase() == 'png'
        ? 'png'
        : extension.toLowerCase() == 'webp'
        ? 'webp'
        : 'jpg';
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$normalized';
    await _client.storage
        .from('news-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: switch (normalized) {
              'png' => 'image/png',
              'webp' => 'image/webp',
              _ => 'image/jpeg',
            },
          ),
        );
    return path;
  }
}
