import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../data/services/club_news_service.dart';
import '../../domain/models/club_news_post.dart';

class ClubNewsEditorScreen extends StatefulWidget {
  const ClubNewsEditorScreen({
    super.key,
    required this.supabaseClient,
    this.post,
  });

  final SupabaseClient supabaseClient;
  final ClubNewsPost? post;

  @override
  State<ClubNewsEditorScreen> createState() => _ClubNewsEditorScreenState();
}

class _ClubNewsEditorScreenState extends State<ClubNewsEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  Uint8List? _imageBytes;
  String? _imageExtension;
  bool _removeExistingImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post?.title);
    _bodyController = TextEditingController(text: widget.post?.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageExtension = file.name.split('.').last;
      _removeExistingImage = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final service = ClubNewsService(widget.supabaseClient);
    try {
      final post = widget.post;
      if (post == null) {
        await service.createPost(
          title: _titleController.text,
          body: _bodyController.text,
          imageBytes: _imageBytes,
          imageExtension: _imageExtension,
        );
      } else {
        await service.updatePost(
          post: post,
          title: _titleController.text,
          body: _bodyController.text,
          newImageBytes: _imageBytes,
          imageExtension: _imageExtension,
          removeImage: _removeExistingImage,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      _showError(error.message);
    } on StorageException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Der Beitrag konnte nicht gespeichert werden.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = widget.post?.imageUrl;
    final showExisting =
        existingImage != null && !_removeExistingImage && _imageBytes == null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.post == null ? 'Beitrag erstellen' : 'Beitrag bearbeiten',
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.navy,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7FA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Überschrift',
                          prefixIcon: Icon(Icons.title_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Bitte eine Überschrift eingeben.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bodyController,
                        maxLength: 4000,
                        minLines: 7,
                        maxLines: 14,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Beitragstext',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Bitte einen Beitragstext eingeben.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      if (_imageBytes != null || showExisting) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: _imageBytes != null
                                ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                : Image.network(
                                    existingImage!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _imageBytes = null;
                            _removeExistingImage = true;
                          }),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Bild entfernen'),
                        ),
                      ],
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _imageBytes != null || showExisting
                              ? 'Anderes Bild auswählen'
                              : 'Bild hinzufügen (optional)',
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.publish_rounded),
                        label: Text(
                          _saving ? 'Wird gespeichert …' : 'Veröffentlichen',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
