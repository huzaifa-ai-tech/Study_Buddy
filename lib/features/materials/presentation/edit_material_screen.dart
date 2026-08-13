import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/study_material.dart';
import '../state/material_bloc.dart';

/// Edit the title and content of an existing material.
class EditMaterialScreen extends StatefulWidget {
  const EditMaterialScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  State<EditMaterialScreen> createState() => _EditMaterialScreenState();
}

class _EditMaterialScreenState extends State<EditMaterialScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.material.title);
    _contentController = TextEditingController(text: widget.material.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Title and content are required.')),
        );
      return;
    }
    setState(() => _saving = true);
    final updated = widget.material.copyWith(title: title, content: content);
    context.read<MaterialBloc>().add(MaterialEdited(updated));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit material',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Content',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Editing changes the notes but keeps your flashcards, quizzes '
            'and study plan.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}