import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'visual_widgets.dart';
import 'secure_token_storage.dart';

// API Endpoints
const String ragEndpoint = '/rag/RAG/';
const String sqlAnalystEndpoint = '/sql_analyst/sql_analysis/';

class DataUploadPage extends StatefulWidget {
  const DataUploadPage({super.key});

  @override
  State<DataUploadPage> createState() => _DataUploadPageState();
}

class _DataUploadPageState extends State<DataUploadPage> {
  String? selectedFileName;
  Uint8List? selectedBytes;
  bool isLoading = false;
  bool isAnalyzing = false;
  String message = '';
  String messageType = ''; // 'success', 'error', 'info'
  final TextEditingController queryController = TextEditingController();
  List<Map<String, dynamic>> resultData = [];
  String? queryAnswer;
  double? executionTime;
  List<String> queryExamples = [
    "Show total sales by product",
    "What are the top 5 selling items?",
    "Calculate monthly revenue trends",
    "Show customer distribution by region",
    "Compare sales performance by quarter",
    "Analyze product return rates",
    "Show inventory turnover ratio",
  ];
  int _selectedExampleIndex = -1;

  @override
  void initState() {
    super.initState();
    // Focus the query field when page loads
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'json', 'xls'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        selectedFileName = file.name;
        selectedBytes = file.bytes;
        message = '';
        messageType = '';
        resultData = [];
        queryAnswer = null;
        executionTime = null;
      });
      _showFileSuccess(file.name);
    }
  }

  void _showFileSuccess(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Selected: $fileName',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> uploadFile() async {
    if (selectedBytes == null || selectedFileName == null) {
      _showMessage('Please select a file first', 'error');
      return;
    }
    
    if (queryController.text.trim().isEmpty) {
      _showMessage('Please enter a query question', 'error');
      return;
    }
    
    setState(() {
      isLoading = true;
      isAnalyzing = true;
      message = '';
      messageType = '';
      resultData = [];
      queryAnswer = null;
      executionTime = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = await SecureTokenStorage.getToken() ?? '';

    try {
      final streamed = await ApiClient.postMultipart(
        '/sql_analyst/sql_analysis/', 
        {'query': queryController.text.trim()}, 
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        }, 
        files: [
          http.MultipartFile.fromBytes('file', selectedBytes!, filename: selectedFileName!),
        ],
      );

      print('Status code: ${streamed.statusCode}'); // Debug
      final body = await streamed.stream.bytesToString();
      print('Response body: $body'); // Debug
      final data;
      try {
        data = json.decode(body);
      } catch (e) {
        _showMessage('Failed to parse response: $e', 'error');
        return;
      }
      
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        setState(() {
          queryAnswer = data['Query'] ?? 'Analysis completed';
          executionTime = double.tryParse(data['Execution Time']?.toString() ?? '0');
          final fullData = List<Map<String, dynamic>>.from(data['Data'] ?? []);
          resultData = fullData.take(100).toList(); // Limit to first 100 rows for performance
          message = '✅ Analysis completed successfully (${fullData.length} total rows, showing first 100)';
          messageType = 'success';
          isAnalyzing = false;
        });
        _showAnalysisSuccess();
      } else {
        _showMessage(data['detail'] ?? 'Analysis failed', 'error');
      }
    } catch (e) {
      _showMessage('Failed to analyze: $e', 'error');
    }

    setState(() => isLoading = false);
  }

  void _showAnalysisSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.analytics, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Analysis completed! View results below',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showMessage(String msg, String type) {
    setState(() {
      message = msg;
      messageType = type;
      isLoading = false;
      isAnalyzing = false;
    });
  }

  void _selectExample(int index, String example) {
    setState(() {
      _selectedExampleIndex = index;
      queryController.text = example;
    });
  }

  Widget _buildFileCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_upload, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).uploadData,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supported formats: CSV, Excel (XLSX/XLS), JSON',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: selectedBytes != null ? const Color(0xFF6366F1).withValues(alpha: 0.05) : Colors.transparent,
                ),
                child: InkWell(
                  onTap: pickFile,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                          Icon(
                            selectedBytes != null ? Icons.check_circle : Icons.folder_open,
                            size: 48,
                            color: selectedBytes != null ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
                          ),
                        const SizedBox(height: 12),
                          Text(
                            selectedBytes != null ? selectedFileName! : AppLocalizations.of(context).selectFile,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: selectedBytes != null ? const Color(0xFF064E3B) : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (selectedBytes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${(selectedBytes!.length / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (selectedBytes != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: pickFile,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
      ),
    );
  }

  Widget _buildQueryCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.question_answer, color: Color(0xFF3B82F6), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).askYourQuestion,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Write a natural language question about your data',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextFormField(
                  controller: queryController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
                  decoration: InputDecoration(
                    hintText: 'e.g., "Show total sales by product category"',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () => queryController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Try these examples:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(queryExamples.length, (index) {
                  return GestureDetector(
                    onTap: () => _selectExample(index, queryExamples[index]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedExampleIndex == index
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                            : const Color(0xFF1E1E28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedExampleIndex == index
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                              : const Color(0xFF2A2A38),
                        ),
                      ),
                      child: Text(
                        queryExamples[index],
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedExampleIndex == index
                              ? const Color(0xFF60A5FA)
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
  }

  Widget _buildResultsSection() {
    if (resultData.isEmpty && queryAnswer == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.analytics, color: AppColors.secondary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).analysisResults,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (executionTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer, color: const Color(0xFF0097A7), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${executionTime?.toStringAsFixed(2) ?? '0.00'}s',
                                style: TextStyle(
                                  color: const Color(0xFF0097A7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (queryAnswer != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📊 ${AppLocalizations.of(context).analysisSummary}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            queryAnswer!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF374151),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (resultData.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      '📋 ${AppLocalizations.of(context).detailedData}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: DataTable(
                            columnSpacing: 24,
                            horizontalMargin: 16,
                            headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                              (states) => const Color(0xFF6366F1).withValues(alpha: 0.1),
                            ),
                            headingRowHeight: 60,
                            dataRowMinHeight: 50,
                            dataRowMaxHeight: 60,
                            border: TableBorder(
                              horizontalInside: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                              verticalInside: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            columns: resultData.first.keys.map((key) {
                              return DataColumn(
                                label: Text(
                                  key.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              );
                            }).toList(),
                            rows: resultData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final row = entry.value;
                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (states) => index.isEven ? Colors.white.withValues(alpha: 0.02) : null,
                                ),
                                cells: row.values.map((value) {
                                  return DataCell(
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 100),
                                      child: Text(
                                        value?.toString() ?? '',
                                        style: TextStyle(
                                          color: Color(0xFF374151),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Chip(
                          label: Text(
                            '${resultData.length} rows shown',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      ],
    );
  }

  Widget _buildMessageCard() {
    if (message.isEmpty) return const SizedBox.shrink();

    Color backgroundColor;
    Color iconColor;
    IconData icon;

    switch (messageType) {
      case 'success':
        backgroundColor = const Color(0xFF6366F1).withValues(alpha: 0.1);
        iconColor = const Color(0xFF6366F1);
        icon = Icons.check_circle;
        break;
      case 'error':
        backgroundColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
        iconColor = const Color(0xFFEF4444);
        icon = Icons.error;
        break;
      default:
        backgroundColor = const Color(0xFFF59E0B).withValues(alpha: 0.1);
        iconColor = const Color(0xFFF59E0B);
        icon = Icons.info;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: iconColor),
              onPressed: () => setState(() {
                message = '';
                messageType = '';
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF020617),
              Color(0xFF0B1120),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  AppLocalizations.of(context).uploadData,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Content Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Ask questions about ',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'your data',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload any CSV, Excel, or JSON file and get instant SQL analysis',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // File Upload Card
                      _buildFileCard(),
                      const SizedBox(height: 24),
                      
                      // Query Input Card
                      _buildQueryCard(),
                      const SizedBox(height: 24),
                      
                      // Message Card
                      _buildMessageCard(),
                      const SizedBox(height: 24),
                      
                      // Analyze Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (isLoading || selectedBytes == null || queryController.text.trim().isEmpty)
                              ? null
                              : uploadFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          ),
                          child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isAnalyzing)
                                      const Text(
                                        'Analyzing your data...',
                                        style: TextStyle(fontSize: 16),
                                      )
                                    else
                                      const Text(
                                        'Processing...',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.psychology, size: 22),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Analyze Data',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Results Section
                      _buildResultsSection(),
                      const SizedBox(height: 40),
                    ],
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