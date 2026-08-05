import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/instagram_post.dart';
import 'instagram_video_screen.dart';

class InstagramPostDetailScreen extends StatelessWidget {
  const InstagramPostDetailScreen({super.key, required this.post});

  final InstagramPost post;

  @override
  Widget build(BuildContext context) {
    final previewUrl = post.previewUrl;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Neuigkeit'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.navy,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Material(
                color: const Color(0xFFF9F7FA),
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (previewUrl != null)
                      GestureDetector(
                        onTap: () => post.isVideo && post.mediaUrl != null
                            ? showInstagramVideo(
                                context,
                                videoUrl: post.mediaUrl!,
                              )
                            : showInstagramImage(context, imageUrl: previewUrl),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                previewUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 900,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, _, _) =>
                                    const _ImageFallback(),
                              ),
                              if (post.isVideo)
                                const Center(child: _DetailVideoPlayBadge()),
                            ],
                          ),
                        ),
                      )
                    else
                      const AspectRatio(
                        aspectRatio: 1,
                        child: _ImageFallback(),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.red,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
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
                                _formatDate(post.timestamp),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            post.caption?.trim().isNotEmpty == true
                                ? post.caption!.trim()
                                : 'Zu diesem Beitrag gibt es keine Beschreibung.',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showInstagramImage(
  BuildContext context, {
  required String imageUrl,
}) async {
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  try {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImage(imageUrl: imageUrl),
      ),
    );
  } finally {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Bild'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, _, _) => const _ImageFallback(dark: true),
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark ? Colors.black : const Color(0xFFEDE9F0),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: dark ? Colors.white70 : AppColors.muted,
          size: 48,
        ),
      ),
    );
  }
}

class _DetailVideoPlayBadge extends StatelessWidget {
  const _DetailVideoPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xCC061E39),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}

String _formatDate(DateTime date) {
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
