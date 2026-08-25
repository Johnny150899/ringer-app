import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/models/club_news_post.dart';
import 'instagram_post_detail_screen.dart';

class ClubNewsDetailScreen extends StatelessWidget {
  const ClubNewsDetailScreen({super.key, required this.post});

  final ClubNewsPost post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Vereinsmeldung'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.navy,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9F7FA),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.imageUrl != null)
                    GestureDetector(
                      onTap: () =>
                          showInstagramImage(context, imageUrl: post.imageUrl!),
                      child: AppNetworkImage(
                        url: post.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 1200,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${post.publishedAt.day}.${post.publishedAt.month}.${post.publishedAt.year}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          post.body,
                          style: const TextStyle(
                            color: AppColors.text,
                            height: 1.5,
                            fontSize: 16,
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
    );
  }
}
