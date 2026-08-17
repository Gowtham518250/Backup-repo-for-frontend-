import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'visual_widgets.dart';
import 'secure_token_storage.dart';

// API Endpoints
const String sqlAnalystEndpoint = ApiClient.sqlAnalystEndpoint;
const String ragEndpoint = ApiClient.ragEndpoint;

class QueryPage extends StatefulWidget {
  const QueryPage({super.key});

  @override
  State<QueryPage> createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> {
  final TextEditingController queryController = TextEditingController();
  String reply = '';
  bool isLoading = false;
  File? selectedFile;

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'json'],
    );

    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> askQuery() async {
    if (queryController.text.trim().isEmpty) return;
    setState(() {
      isLoading = true;
      reply = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final token = await SecureTokenStorage.getToken() ?? '';

    try {
      if (selectedFile != null) {
        // Use RAG with file
        final streamed = await ApiClient.postMultipart(ApiClient.ragEndpoint, {
          'query': queryController.text.trim(),
        }, headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        }, files: [
          await http.MultipartFile.fromPath('file', selectedFile!.path),
        ]);

        final body = await streamed.stream.bytesToString();
        if (streamed.statusCode == 200) {
          final data = json.decode(body);
          setState(() => reply = 'Answer: ${data['answer']}');
        } else {
          setState(() => reply = 'Error: ${streamed.statusCode} - $body');
        }
      } else {
        // Query database directly without file
        final response = await ApiClient.postForm(ApiClient.sqlAnalystEndpoint, {
          'query': queryController.text.trim(),
        }, headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() => reply = 'SQL Query: ${data['Query']}\n\nResult: ${data['Data']}');
        } else {
          setState(() => reply = 'Error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      setState(() => reply = 'Unable to connect to server: $e');
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).askSimpleLanguage),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: queryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context).askQuestionHint,
                          labelStyle:
                              TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: Text(
                                selectedFile != null
                                    ? 'File: ${selectedFile!.path.split('\\').last}'
                                    : '${AppLocalizations.of(context).selectFile} (Optional)',
                                overflow: TextOverflow.ellipsis,
                              ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                  foregroundColor: const Color(0xFF6366F1),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading ? null : askQuery,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      AppLocalizations.of(context).askButton,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context).queryTip,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      child: Text(
                        reply.isEmpty ? AppLocalizations.of(context).responseHint : reply,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
