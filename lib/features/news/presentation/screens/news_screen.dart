import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../data/services/club_news_service.dart';
import '../../data/services/instagram_news_service.dart';
import '../../domain/models/club_news_post.dart';
import '../../domain/models/instagram_post.dart';
import '../widgets/news_header.dart';
import '../widgets/news_post_cards.dart';
import 'club_news_editor_screen.dart';

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
      // Instagram-News bleiben sichtbar, solange Vereinsnews nicht laden.
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
    setState(() => _content = SynchronousFuture(content));
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
                child: NewsHeader(
                  canPublish: widget.canPublishClubNews,
                  onCreate: _openEditor,
                ),
              ),
              if (content.clubPosts.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: NewsSectionTitle('Aus dem Verein'),
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
                      return ClubPostCard(
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
                const SliverToBoxAdapter(child: NewsSectionTitle('Instagram')),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                  sliver: SliverList.separated(
                    itemCount: content.instagramPosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, index) =>
                        InstagramPostCard(post: content.instagramPosts[index]),
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
