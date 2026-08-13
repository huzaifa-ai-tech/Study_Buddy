import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../data/models/study_material.dart';
import '../state/material_bloc.dart';

/// Add a new study material by pasting text or importing a PDF.
class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({super.key});

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isPdfSource = false;
  String? _pdfPath;
  String? _pdfName;
  bool _isExtracting = false;
  String? _extractError;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New material')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Machine Learning Basics',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Paste text'),
                    icon: Icon(Icons.edit_note_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Import PDF'),
                    icon: Icon(Icons.picture_as_pdf_rounded),
                  ),
                ],
                selected: {_isPdfSource},
                onSelectionChanged: (s) =>
                    setState(() => _isPdfSource = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              if (!_isPdfSource)
                TextFormField(
                  controller: _contentController,
                  minLines: 10,
                  maxLines: 18,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Study notes',
                    hintText:
                        'Paste your lecture notes, article or textbook content here...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Paste some notes or pick a PDF'
                      : null,
                )
              else
                _buildPdfPicker(),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save material'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPicker() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kIsWeb)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'PDF import is available on Android and iOS.',
              style: TextStyle(fontSize: 13),
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: _isExtracting ? null : _pickPdf,
            icon: _isExtracting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(
              _pdfName ?? 'Choose a PDF file',
            ),
          ),
          if (_extractError != null) ...[
            const SizedBox(height: 8),
            Text(
              _extractError!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ],
          if (_pdfPath != null) ...[
            const SizedBox(height: 8),
            Text(
              'Selected: $_pdfName',
              style: TextStyle(color: scheme.primary, fontSize: 13),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickPdf() async {
    setState(() {
      _isExtracting = true;
      _extractError = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = result?.files.single.path;
      if (path == null) {
        setState(() => _isExtracting = false);
        return;
      }
      final text = await _extractPdfText(path);
      _contentController.text = text;
      setState(() {
        _pdfPath = path;
        _pdfName = result!.files.single.name;
        _isExtracting = false;
        if (text.trim().isEmpty) {
          _extractError = 'No text could be extracted from this PDF.';
        }
      });
    } catch (e) {
      setState(() {
        _isExtracting = false;
        _extractError = 'Could not read the PDF: $e';
      });
    }
  }

  Future<String> _extractPdfText(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('File not found');
    final doc = await PdfDocument.openFile(path);
    try {
      final buffer = StringBuffer();
      for (final page in doc.pages) {
        final raw = await page.loadText();
        buffer.writeln(raw?.fullText ?? '');
      }
      return buffer.toString().trim();
    } finally {
      await doc.dispose();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isPdfSource && (_pdfPath == null || _contentController.text.isEmpty)) {
      if (_pdfPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a PDF file first')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text could be extracted from this PDF')),
      );
      return;
    }
    final material = StudyMaterial(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      sourceType: _isPdfSource ? 'pdf' : 'text',
      fileName: _pdfName,
    );
    context.read<MaterialBloc>().add(MaterialAdded(material));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material saved')),
    );
  }
}