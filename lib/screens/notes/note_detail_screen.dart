import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/date_utils.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

/// Note detail screen showing the full content of a single note.
///
/// Convex queries/mutations used:
/// - `notes.getNote` — fetch the note by slug / ID
/// - `notes.updateNote` — save edits to the note
/// - `notes.deleteNote` — delete the note
class NoteDetailScreen extends ConsumerStatefulWidget {
  /// URL-friendly slug or Convex document ID of the note.
  final String slug;

  const NoteDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  bool _isEditing = false;
  late final TextEditingController _contentController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Finds the note from the global notes provider by ID/slug.
  Note? _findNote(List<Note> notes) {
    for (final note in notes) {
      if (note.id == widget.slug) return note;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

    return notesAsync.when(
      data: (notes) {
        final note = _findNote(notes);

        if (note == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note')),
            body: const Center(
              child: Text('Note not found', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        // Initialize content controller from real data on first load.
        if (!_initialized) {
          _contentController.text = note.content;
          _initialized = true;
        }

        return _buildNoteDetail(context, note);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 60, color: Colors.white),
                const SizedBox(height: 16),
                Container(height: 30, width: 80, color: Colors.white),
                const SizedBox(height: 16),
                Container(height: 100, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: ErrorStateView(error: error, prefix: 'Error'),
      ),
    );
  }

  Widget _buildNoteDetail(BuildContext context, Note note) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            tooltip: _isEditing ? 'Save' : 'Edit',
            onPressed: () {
              if (_isEditing) {
                _handleSave(note);
              }
              setState(() => _isEditing = !_isEditing);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleMenuAction(action, note),
            itemBuilder: (context) => [
              if (note.youtubeVideoId != null)
                const PopupMenuItem(
                  value: 'play',
                  child: ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text('Go to video'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video reference card
            if (note.youtubeVideoId != null) ...[
              _buildVideoReference(context, note),
              const SizedBox(height: 16),
            ],

            // Timestamp badge
            if (note.isTimestamped) ...[
              _buildTimestampBadge(context, note),
              const SizedBox(height: 16),
            ],

            // Note content
            _isEditing
                ? TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write your note...',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                : Text(
                    note.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
            const SizedBox(height: 24),

            // Metadata
            _buildMetadata(context, note),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoReference(BuildContext context, Note note) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 64,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.play_circle_outline, size: 24),
        ),
        title: Text(
          note.youtubeVideoId ?? 'Video',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text('Tap to view video'),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () {
          // TODO: navigate to play screen at this note's timestamp
        },
      ),
    );
  }

  Widget _buildTimestampBadge(BuildContext context, Note note) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            // TODO: navigate to video at this timestamp
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  note.formattedTimestamp ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata(BuildContext context, Note note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Created: ${note.createdAt != null ? formatDate(note.createdAt) : 'Unknown'}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Future<void> _handleSave(Note note) async {
    try {
      await updateNote(ref, note.id, _contentController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Failed to save note');
      }
    }
  }

  void _handleMenuAction(String action, Note note) {
    switch (action) {
      case 'play':
        // TODO: navigate to play screen at note timestamp
        break;
      case 'share':
        // TODO: share note
        break;
      case 'delete':
        _showDeleteConfirmation(note);
        break;
    }
  }

  void _showDeleteConfirmation(Note note) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await deleteNote(ref, note.id);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) {
                  showErrorSnackBar(
                    context,
                    error: e,
                    prefix: 'Failed to delete',
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
