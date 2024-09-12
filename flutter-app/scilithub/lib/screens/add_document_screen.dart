
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../config.dart';  // Import the config file

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({Key? key}) : super(key: key);

  @override
  _AddDocumentScreenState createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  String title = '';
  String tags = '';
  String summary = '';
  String content = '';
  int rating = 0;
  File? selectedPdfFile;

  bool isSubmitting = false;

  


Future<void> createDocument() async {
  print('Creating document...');  // Logging for debugging
  final response = await http.post(
    Uri.parse('${Config.apiUrl}/documents'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode({
      'title': title,
      'tags': tags.split(',').map((tag) => tag.trim()).toList(),
      'summary': summary,
      'content': content,
      'rating': rating,
    }),
  );

  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');

  if (response.statusCode == 201 || response.statusCode == 200) {
    final document = jsonDecode(response.body);

    // Access the document ID directly from the "$oid" field
    if (document['\$oid'] != null) {
      String documentId = document['\$oid'];
      print('Document created successfully with ID: $documentId');
      
      // Proceed to upload the PDF
      if (selectedPdfFile != null) {
        await uploadPdf(documentId);
      }
    } else {
      print('Document creation response does not contain "oid" field.');
    }
  } else {
    print('Failed to create document. Status code: ${response.statusCode}');
  }
}



  Future<void> uploadPdf(String documentId) async {
    if (selectedPdfFile == null) {
      print('No PDF file selected.');  // Logging if no file is selected
      return;
    }

    print('Uploading PDF...');  // Logging for debugging
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${Config.apiUrl}/upload_pdf/$documentId'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', selectedPdfFile!.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      print('PDF uploaded successfully');
    } else {
      print('Failed to upload PDF. Status code: ${response.statusCode}');
    }
  }

  void pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        selectedPdfFile = File(result.files.single.path!);
      });
      print('Selected file: ${selectedPdfFile!.path}');
    } else {
      print('No file selected.');
    }
  }

  
Future<void> handleSubmit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    isSubmitting = true;
  });

  String? documentId;

  // First, create the document
  final response = await http.post(
    Uri.parse('${Config.apiUrl}/documents'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode({
      'title': title,
      'tags': tags.split(',').map((tag) => tag.trim()).toList(),
      'summary': summary,
      'content': content,
      'rating': rating,
    }),
  );

  if (response.statusCode == 201 || response.statusCode == 200) {
    final document = jsonDecode(response.body);
    documentId = document['\$oid']; // Assuming the ID is returned like this
    print('Document created with ID: $documentId');

    // Upload the PDF if a file was selected
    
    if (documentId != null && selectedPdfFile != null) {
      await uploadPdf(documentId);  // Now it's safe to call uploadPdf
    }

  }

  setState(() {
    isSubmitting = false;
  });

  // Pass a success result to the previous screen
  if (documentId != null) {
    Navigator.pop(context, true);  // 'true' indicates success
  } else {
    Navigator.pop(context, false); // 'false' indicates failure
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Document'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (value) {
                  setState(() {
                    title = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                onChanged: (value) {
                  setState(() {
                    tags = value;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Summary'),
                onChanged: (value) {
                  setState(() {
                    summary = value;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Content'),
                onChanged: (value) {
                  setState(() {
                    content = value;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Rating (1-5)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    rating = int.parse(value);
                  });
                },
              ),
              const SizedBox(height: 20),
              
              // PDF Upload Section
              ElevatedButton(
                onPressed: pickPdfFile,
                child: const Text('Select PDF'),
              ),
              if (selectedPdfFile != null)
                Text('Selected file: ${selectedPdfFile!.path.split('/').last}'),
              
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: isSubmitting ? null : handleSubmit,
                child: isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Save Document and Upload PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

