import 'package:flutter/material.dart';
import 'screens/document_list_screen.dart';
import 'screens/add_edit_document_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const DocumentListScreen(),
        '/add': (context) => const AddEditDocumentScreen(),
      },
    );
  }
}
