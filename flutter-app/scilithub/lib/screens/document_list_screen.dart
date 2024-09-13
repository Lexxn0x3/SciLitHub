
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';  // Import the config file
import 'document_detail_screen.dart';  // Import the DocumentDetailScreen
import 'add_document_screen.dart';  // Import the AddDocumentScreen
import '../api_key_manager.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({Key? key}) : super(key: key);

  @override
  _DocumentListScreenState createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  List documents = [];
  bool isLoading = true;
  

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments([String term = '']) async {
    setState(() {
      isLoading = true;
    });
    String? apiKey = await loadApiKey();
    if (apiKey == null) {
      String enteredKey = await promptForApiKey(context);
      await saveApiKey(enteredKey);
    }
    
    final url = term.isEmpty
        ? '${Config.apiUrl}/documents'   // Use the base API URL from Config
        : '${Config.apiUrl}/search?term=$term';
    
    final response = await http.get
    (Uri.parse(url),
    headers: {'x-api-key': apiKey??''},
    );

    if (response.statusCode == 200) {
      setState(() {
        documents = json.decode(response.body);
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Document Manager'),
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return ListTile(
                title: Text(document['title']),
                subtitle: Text(document['tags'].join(', ')),
                onTap: () {
                  // Navigate to the DocumentDetailScreen and wait for the result
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentDetailScreen(document: document),
                    ),
                  ).then((result) {
                    if (result == true) {
                      // If result is true (document was edited or deleted), refresh the document list
                      fetchDocuments();
                    }
                  });
                },
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Wait for the result from AddDocumentScreen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDocumentScreen()),
          );

          // If a document was added, refresh the document list
          if (result == true) {
            fetchDocuments();  // Refresh the list
          }
        },
        child: const Icon(Icons.add),  // Plus icon
        tooltip: 'Add Document',
      ),
    );
  }
}

