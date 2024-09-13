import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Function to load the API key from SharedPreferences
Future<String?> loadApiKey() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('api_key');
}

// Function to save the API key to SharedPreferences
Future<void> saveApiKey(String apiKey) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('api_key', apiKey);
}

// Function to prompt the user for the API key
Future<String> promptForApiKey(BuildContext context) async {
  TextEditingController _apiKeyController = TextEditingController();

  return await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Enter API Key'),
        content: TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(hintText: "API Key"),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () {
              Navigator.of(context).pop(_apiKeyController.text); // Return the API key
            },
          ),
        ],
      );
    },
  );
}
