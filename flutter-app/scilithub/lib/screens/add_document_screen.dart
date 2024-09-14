
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../config.dart';  // Import the config file
import '../api_key_manager.dart';
import 'package:flutter/foundation.dart';  // Import for kIsWeb

Uint8List? selectedPdfFileBytes;
String? selectedPdfFileName;

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

Future<void> uploadPdf(String documentId) async {
  String? apiKey = await loadApiKey();  // Load the API key

  final uri = Uri.parse('${Config.apiUrl}/upload_pdf/$documentId');

  var request = http.MultipartRequest('POST', uri);

  // Add the API key to the headers
  request.headers['x-api-key'] = apiKey ?? '';

  if (kIsWeb) {
    // On web, use the bytes to upload the file
    var fileBytes = selectedPdfFileBytes; // Uint8List from file picker
    var fileName = selectedPdfFileName;   // Name of the file

    // Add the file bytes to the request
    request.files.add(http.MultipartFile.fromBytes(
      'file', 
      fileBytes!,
      filename: fileName,
    ));
  } else {
    // On mobile/desktop, use the file path
    request.files.add(await http.MultipartFile.fromPath('file', selectedPdfFile!.path));
  }

  // Send the request and handle the response
  var response = await request.send();

  if (response.statusCode == 200) {
    print('File uploaded successfully');
  } else {
    print('File upload failed with status: ${response.statusCode}');
  }
}

void pickPdfFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result != null) {
    if (kIsWeb) {
      // On web, save bytes and name
      selectedPdfFileBytes = result.files.single.bytes;
      selectedPdfFileName = result.files.single.name;
    } else {
      // On mobile/desktop, save the file path
      setState(() {
        selectedPdfFile = File(result.files.single.path!);
      });
    }
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
  String? apiKey = await loadApiKey();

  // First, create the document
  final response = await http.post(
    Uri.parse('${Config.apiUrl}/documents'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'x-api-key': apiKey??'',
    },
    body: jsonEncode({
      'title': title,
      'tags': tags.split(',').map((tag) => tag.trim()).toList(),
      'summary': summary,
      'content': content,
      'rating': rating,
    }),
  );
  print("doc created" + response.statusCode.toString());
  if (response.statusCode == 201 || response.statusCode == 200) {
    final document = jsonDecode(response.body);
    documentId = document['\$oid']; // Assuming the ID is returned like this
    print('Document created with ID: $documentId file: $selectedPdfFile');

    // Upload the PDF if a file was selected
    
    if (documentId != null && selectedPdfFileBytes != null) {
      print("uploading pdf.....");
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

