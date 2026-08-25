class InstagramPost {
  const InstagramPost({
    required this.id,
    required this.mediaType,
    required this.permalink,
    required this.timestamp,
    this.caption,
    this.mediaUrl,
    this.thumbnailUrl,
  });

  factory InstagramPost.fromJson(Map<String, dynamic> json) {
    return InstagramPost(
      id: json['id'] as String,
      caption: json['caption'] as String?,
      mediaType: json['media_type'] as String? ?? 'IMAGE',
      mediaUrl: json['media_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      permalink: json['permalink'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }

  final String id;
  final String? caption;
  final String mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String permalink;
  final DateTime timestamp;

  bool get isVideo => mediaType == 'VIDEO' || mediaType == 'REELS';

  String? get previewUrl =>
      isVideo ? thumbnailUrl ?? mediaUrl : mediaUrl ?? thumbnailUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'caption': caption,
    'media_type': mediaType,
    'media_url': mediaUrl,
    'thumbnail_url': thumbnailUrl,
    'permalink': permalink,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}
