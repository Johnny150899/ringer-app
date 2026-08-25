class ClubNewsPost {
  const ClubNewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.publishedAt,
    this.imagePath,
    this.imageUrl,
  });

  factory ClubNewsPost.fromJson(Map<String, dynamic> json, {String? imageUrl}) {
    return ClubNewsPost(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      imagePath: json['image_path'] as String?,
      imageUrl: imageUrl,
      createdBy: json['created_by'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String).toLocal(),
    );
  }

  final int id;
  final String title;
  final String body;
  final String? imagePath;
  final String? imageUrl;
  final String createdBy;
  final DateTime publishedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'image_path': imagePath,
    'image_url': imageUrl,
    'created_by': createdBy,
    'published_at': publishedAt.toUtc().toIso8601String(),
  };
}
