
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../config.dart';  // Import the config file

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
    try {
      final response = await http.get(Uri.parse('${Config.apiUrl}/pdf/$documentId'));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document['title'] ?? 'Document Detail'),
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

