import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/features/news/models/instagram_post.dart';

void main() {
  test('image post uses its media URL as preview', () {
    final post = InstagramPost.fromJson({
      'id': 'image-1',
      'media_type': 'IMAGE',
      'media_url': 'https://example.com/image.jpg',
      'permalink': 'https://instagram.com/p/image-1',
      'timestamp': '2026-08-05T12:00:00+0000',
      'caption': List.filled(40, 'Ein langer Vereinsbericht.').join(' '),
    });

    expect(post.previewUrl, 'https://example.com/image.jpg');
    expect(post.caption!.length, greaterThan(400));
  });

  test('video and reel posts prefer their thumbnail as preview', () {
    for (final mediaType in ['VIDEO', 'REELS']) {
      final post = InstagramPost.fromJson({
        'id': mediaType,
        'media_type': mediaType,
        'media_url': 'https://example.com/video.mp4',
        'thumbnail_url': 'https://example.com/thumbnail.jpg',
        'permalink': 'https://instagram.com/reel/video-1',
        'timestamp': '2026-08-05T12:00:00+0000',
      });

      expect(post.previewUrl, 'https://example.com/thumbnail.jpg');
      expect(post.mediaUrl, 'https://example.com/video.mp4');
    }
  });
}
