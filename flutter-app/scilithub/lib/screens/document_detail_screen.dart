import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../config.dart';  // Import the config file
import '../api_key_manager.dart';
import 'add_edit_document_screen.dart';  // Import the Add/Edit screen

class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const DocumentDetailScreen({Key? key, required this.document}) : super(key: key);

  @override
  _DocumentDetailScreenState createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  String localPath = "";
  bool isLoading = true;
  bool hasPdf = true;

  @override
  void initState() {
    super.initState();

    // Extract the actual document ID from the MongoDB _id field
    final documentId = widget.document['_id']?['\$oid'] ?? '';

    // Pass the document ID to fetch the PDF
    if (documentId.isNotEmpty) {
      loadPdf(documentId);
    } else {
      setState(() {
        hasPdf = false;
        isLoading = false;
      });
    }
  }

  Future<void> loadPdf(String documentId) async {
    String? apiKey = await loadApiKey();
    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/pdf/$documentId'),
        headers: {'x-api-key': apiKey ?? ''},
      );

      // Check if PDF is available
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/document.pdf");
        await file.writeAsBytes(bytes, flush: true);
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      } else {
        setState(() {
          hasPdf = false;  // No PDF available for this document
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasPdf = false;
        isLoading = false;
      });
    }
  }

  Future<void> deleteDocument(String documentId) async {
  String? apiKey = await loadApiKey();

  try {
    final response = await http.delete(
      Uri.parse('${Config.apiUrl}/documents/$documentId'),
      headers: {'x-api-key': apiKey ?? ''},
    );

    if (response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted successfully.')),
      );
      Navigator.pop(context, true);  // Return true to indicate deletion
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete the document.')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('An error occurred while deleting the document.')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    final documentId = widget.document['_id']?['\$oid'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document['title'] ?? 'Document Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditDocumentScreen(document: widget.document),
                ),
              );
              if (result == true) {
                Navigator.pop(context, true);  // Return true to indicate the document was edited
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              // Show confirmation dialog before deleting
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Delete Document'),
                    content: const Text('Are you sure you want to delete this document?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true) {
                deleteDocument(documentId);
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Title: ${widget.document['title'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tags: ${widget.document['tags'] != null ? widget.document['tags'].join(', ') : 'N/A'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  'Summary: ${widget.document['summary'] ?? 'No summary available'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  'Content: ${widget.document['content'] ?? 'No content available'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  'Rating: ${widget.document['rating'] != null ? widget.document['rating'].toString() : 'No rating'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(),

          // PDF Viewer Section (Expanded to take up remaining space)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasPdf
                    ? PdfViewer.file(localPath)  // Display the PDF
                    : const Center(
                        child: Text('No PDF available for this document.'),
                      ),
          ),
        ],
      ),
    );
  }
}
