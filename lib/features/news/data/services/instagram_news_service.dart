import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/instagram_post.dart';

class InstagramNewsService {
  const InstagramNewsService(this._client);

  final SupabaseClient _client;

  Future<List<InstagramPost>> loadPosts() async {
    final response = await _client.functions
        .invoke('instagram-feed')
        .timeout(const Duration(seconds: 8));
    final body = response.data;
    if (body is! Map || body['posts'] is! List) {
      throw const FormatException('Ungültige Antwort des Instagram-Feeds.');
    }

    return (body['posts'] as List)
        .whereType<Map>()
        .map((post) => InstagramPost.fromJson(Map<String, dynamic>.from(post)))
        .toList(growable: false);
  }
}
