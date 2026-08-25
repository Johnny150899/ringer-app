import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/models/club_news_post.dart';
import '../../domain/models/instagram_post.dart';
import '../screens/club_news_detail_screen.dart';
import '../screens/instagram_post_detail_screen.dart';
import '../screens/instagram_video_screen.dart';

class ClubPostCard extends StatelessWidget {
  const ClubPostCard({
    super.key,
    required this.post,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final ClubNewsPost post;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9F7FA),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ClubNewsDetailScreen(post: post),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: AppNetworkImage(
                  url: post.imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  placeholder: const MediaFallback(),
                  errorWidget: const MediaFallback(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        color: AppColors.red,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          formatNewsDate(post.publishedAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canManage)
                        PopupMenuButton<String>(
                          tooltip: 'Beitrag verwalten',
                          onSelected: (value) =>
                              value == 'edit' ? onEdit() : onDelete(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Bearbeiten'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Löschen'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    post.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.text, height: 1.35),
                  ),
                  const SizedBox(height: 11),
                  const Row(
                    children: [
                      Text(
                        'Beitrag lesen',
                        style: TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.red,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstagramPostCard extends StatelessWidget {
  const InstagramPostCard({super.key, required this.post});

  final InstagramPost post;

  @override
  Widget build(BuildContext context) {
    final previewUrl = post.previewUrl;
    return Material(
      color: const Color(0xFFF9F7FA),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previewUrl != null)
            GestureDetector(
              onTap: () => post.isVideo && post.mediaUrl != null
                  ? showInstagramVideo(context, videoUrl: post.mediaUrl!)
                  : showInstagramImage(context, imageUrl: previewUrl),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      url: previewUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                      placeholder: const MediaFallback(),
                      errorWidget: const MediaFallback(),
                    ),
                    if (post.isVideo) const Center(child: VideoPlayBadge()),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'ksc_olympia_graben_neudorf',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      formatNewsDate(post.timestamp),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InstagramPostDetailScreen(post: post),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.caption?.trim().isNotEmpty == true)
                          Text(
                            post.caption!.trim(),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              height: 1.35,
                            ),
                          ),
                        const SizedBox(height: 11),
                        const Text(
                          'Vollständigen Beitrag lesen  →',
                          style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatNewsDate(DateTime date) {
  const months = [
    'Jan.',
    'Feb.',
    'März',
    'Apr.',
    'Mai',
    'Juni',
    'Juli',
    'Aug.',
    'Sept.',
    'Okt.',
    'Nov.',
    'Dez.',
  ];
  return '${date.day}. ${months[date.month - 1]} ${date.year}';
}

class MediaFallback extends StatelessWidget {
  const MediaFallback({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEDE9F0),
    child: Center(
      child: Icon(Icons.image_outlined, color: AppColors.muted, size: 48),
    ),
  );
}

class VideoPlayBadge extends StatelessWidget {
  const VideoPlayBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 58,
    decoration: const BoxDecoration(
      color: Color(0xCC061E39),
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
  );
}
