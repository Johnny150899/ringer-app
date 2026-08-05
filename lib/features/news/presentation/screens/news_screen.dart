import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../models/club_news_post.dart';
import '../../models/instagram_post.dart';
import '../../services/club_news_service.dart';
import '../../services/instagram_news_service.dart';
import 'club_news_editor_screen.dart';
import 'club_news_detail_screen.dart';
import 'instagram_post_detail_screen.dart';
import 'instagram_video_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({
    super.key,
    required this.supabaseClient,
    required this.canPublishClubNews,
    required this.isAdmin,
  });

  final SupabaseClient? supabaseClient;
  final bool canPublishClubNews;
  final bool isAdmin;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<_NewsContent> _content;

  @override
  void initState() {
    super.initState();
    _content = _loadContent();
  }

  Future<_NewsContent> _loadContent() async {
    final client = widget.supabaseClient;
    if (client == null) return const _NewsContent();

    List<ClubNewsPost> clubPosts = const [];
    List<InstagramPost> instagramPosts = const [];
    try {
      clubPosts = await ClubNewsService(client).loadPosts();
    } catch (_) {
      // Die Instagram-News bleiben sichtbar, solange die Migration fehlt.
    }
    try {
      instagramPosts = await InstagramNewsService(client).loadPosts();
    } catch (_) {
      // Vereinsbeiträge bleiben auch bei einem Instagram-Fehler sichtbar.
    }
    return _NewsContent(clubPosts: clubPosts, instagramPosts: instagramPosts);
  }

  Future<void> _refresh() async {
    final content = await _loadContent();
    if (!mounted) return;
    setState(() {
      _content = SynchronousFuture(content);
    });
  }

  Future<void> _openEditor([ClubNewsPost? post]) async {
    final client = widget.supabaseClient;
    if (client == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ClubNewsEditorScreen(supabaseClient: client, post: post),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _deletePost(ClubNewsPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: Text('„${post.title}“ wird dauerhaft gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.supabaseClient == null) return;
    try {
      await ClubNewsService(widget.supabaseClient!).deletePost(post);
      await _refresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_NewsContent>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final content = snapshot.data ?? const _NewsContent();
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.red,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _NewsHeader(
                  canPublish: widget.canPublishClubNews,
                  onCreate: _openEditor,
                ),
              ),
              if (content.clubPosts.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionTitle('Aus dem Verein'),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  sliver: SliverList.separated(
                    itemCount: content.clubPosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, index) {
                      final post = content.clubPosts[index];
                      final canManage =
                          widget.isAdmin ||
                          post.createdBy ==
                              widget.supabaseClient?.auth.currentUser?.id;
                      return _ClubPostCard(
                        post: post,
                        canManage: canManage,
                        onEdit: () => _openEditor(post),
                        onDelete: () => _deletePost(post),
                      );
                    },
                  ),
                ),
              ],
              if (content.instagramPosts.isNotEmpty) ...[
                const SliverToBoxAdapter(child: _SectionTitle('Instagram')),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                  sliver: SliverList.separated(
                    itemCount: content.instagramPosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, index) =>
                        _InstagramPostCard(post: content.instagramPosts[index]),
                  ),
                ),
              ],
              if (content.clubPosts.isEmpty && content.instagramPosts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Noch keine Beiträge vorhanden.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NewsContent {
  const _NewsContent({
    this.clubPosts = const [],
    this.instagramPosts = const [],
  });

  final List<ClubNewsPost> clubPosts;
  final List<InstagramPost> instagramPosts;
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({required this.canPublish, required this.onCreate});

  final bool canPublish;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Neuigkeiten',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canPublish)
                Tooltip(
                  message: 'Vereinsbeitrag erstellen',
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onCreate,
                      customBorder: const CircleBorder(),
                      child: const SizedBox.square(
                        dimension: 42,
                        child: Icon(
                          Icons.post_add_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktuelles aus dem Verein und von Instagram',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ClubPostCard extends StatelessWidget {
  const _ClubPostCard({
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
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) => const _MediaFallback(),
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
                          _formatDate(post.publishedAt),
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

class _InstagramPostCard extends StatelessWidget {
  const _InstagramPostCard({required this.post});
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
                    Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                      errorBuilder: (_, _, _) => const _MediaFallback(),
                    ),
                    if (post.isVideo) const Center(child: _VideoPlayBadge()),
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
                      _formatDate(post.timestamp),
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

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEDE9F0),
    child: Center(
      child: Icon(Icons.image_outlined, color: AppColors.muted, size: 48),
    ),
  );
}

class _VideoPlayBadge extends StatelessWidget {
  const _VideoPlayBadge();
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
