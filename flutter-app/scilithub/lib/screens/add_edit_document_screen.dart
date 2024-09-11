import 'package:flutter/material.dart';

class AddEditDocumentScreen extends StatelessWidget {
  const AddEditDocumentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add/Edit Document'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 5,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Call API to add/edit document
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
