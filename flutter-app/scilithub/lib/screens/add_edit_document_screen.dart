import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';  // Import your config for the API URL
import '../api_key_manager.dart';  // Import API key manager

class AddEditDocumentScreen extends StatefulWidget {
  final Map<String, dynamic>? document;

  const AddEditDocumentScreen({Key? key, this.document}) : super(key: key);

  @override
  _AddEditDocumentScreenState createState() => _AddEditDocumentScreenState();
}

class _AddEditDocumentScreenState extends State<AddEditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;

  bool isEdit = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with document data if editing
    isEdit = widget.document != null;
    _titleController = TextEditingController(text: widget.document?['title'] ?? '');
    _contentController = TextEditingController(text: widget.document?['content'] ?? '');
    _tagsController = TextEditingController(text: widget.document?['tags']?.join(', ') ?? '');
    _summaryController = TextEditingController(text: widget.document?['summary'] ?? '');
    _ratingController = TextEditingController(text: widget.document?['rating']?.toString() ?? '');
  }

  Future<void> saveDocument() async {
  if (_formKey.currentState!.validate()) {
    String? apiKey = await loadApiKey();

    final document = {
      'title': _titleController.text,
      'content': _contentController.text,
      'tags': _tagsController.text.split(',').map((tag) => tag.trim()).toList(),
      'summary': _summaryController.text,
      'rating': int.tryParse(_ratingController.text) ?? 0,
    };

    final documentId = widget.document?['_id']?['\$oid'] ?? '';

    final response = isEdit
        ? await http.put(
            Uri.parse('${Config.apiUrl}/documents/$documentId'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey ?? '',
            },
            body: jsonEncode(document),
          )
        : await http.post(
            Uri.parse('${Config.apiUrl}/documents'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey ?? '',
            },
            body: jsonEncode(document),
          );

    if (response.statusCode == 200 || response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved successfully')),
      );
      Navigator.pop(context, true);  // Return true to indicate that the document was saved or edited
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save document')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Document' : 'Add Document'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter content' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(labelText: 'Summary'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ratingController,
                decoration: const InputDecoration(labelText: 'Rating (0 - 5)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final rating = int.tryParse(value ?? '');
                  if (rating == null || rating < 0 || rating > 5) {
                    return 'Please enter a valid rating between 0 and 5';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saveDocument,
                child: Text(isEdit ? 'Update Document' : 'Add Document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
