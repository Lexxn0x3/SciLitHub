import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> document;
  const DocumentDetailScreen({Key? key, required this.document}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document['title']),
      ),
      body: Column(
        children: [
          Expanded(
            child: SfPdfViewer.network(document['pdf_url']),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              // Handle annotation or note-taking
            },
            child: const Text('Annotate'),
          ),
        ],
      ),
    );
  }
}
