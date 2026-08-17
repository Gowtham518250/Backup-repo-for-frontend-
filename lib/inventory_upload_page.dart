import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'api_client.dart';
import 'loading_states.dart';
import 'empty_state_widget.dart';

/// Inventory Upload Page for CSV, Excel, and JSON files
class InventoryUploadPage extends StatefulWidget {
  const InventoryUploadPage({super.key});

  @override
  State<InventoryUploadPage> createState() => _InventoryUploadPageState();
}

class _InventoryUploadPageState extends State<InventoryUploadPage> {
  File? _selectedFile;
  bool _isUploading = false;
  String _uploadMessage = '';
  String _uploadStatus = ''; // success, error, info
  List<UploadHistory> _uploadHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUploadHistory();
  }

  Future<void> _loadUploadHistory() async {
    // Load from SharedPreferences or local storage
    // For now, keeping it simple
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'json', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.first.path!);
          _uploadMessage = '';
          _uploadStatus = '';
        });
      }
    } catch (e) {
      setState(() {
        _uploadMessage = 'Error picking file: $e';
        _uploadStatus = 'error';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      setState(() {
        _uploadMessage = 'Please select a file first';
        _uploadStatus = 'error';
      });
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileName = _selectedFile!.path.split('/').last;
      final fileExtension = fileName.split('.').last.toLowerCase();

      // Validate file
      if (!['csv', 'xlsx', 'xls', 'json', 'txt'].contains(fileExtension)) {
        throw 'Invalid file format. Allowed: CSV, XLSX, XLS, JSON, TXT';
      }

      // Upload via API
      final response = await ApiClient.uploadFile(
        '${ApiClient.inventoryPrefix}/upload',
        _selectedFile!,
      );

      if (response.statusCode == 200) {
        setState(() {
          _uploadMessage = 'File uploaded successfully!';
          _uploadStatus = 'success';
          _uploadHistory.insert(
            0,
            UploadHistory(
              fileName: fileName,
              uploadTime: DateTime.now(),
              status: 'success',
            ),
          );
          _selectedFile = null;
        });
      } else {
        throw 'Upload failed: ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        _uploadMessage = 'Error: $e';
        _uploadStatus = 'error';
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          'Upload Inventory',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: _isUploading
          ? AnimatedLoadingWidget(
              message: 'Uploading file...',
              type: LoadingType.wave,
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Section
                    _buildUploadSection(isDarkMode),
                    const SizedBox(height: 24),

                    // File Info
                    if (_selectedFile != null) _buildFileInfo(isDarkMode),
                    const SizedBox(height: 24),

                    // Message
                    if (_uploadMessage.isNotEmpty)
                      _buildMessageBox(isDarkMode),
                    const SizedBox(height: 24),

                    // Upload Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedFile != null ? _uploadFile : null,
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('Upload File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Template Downloads
                    _buildTemplateSection(isDarkMode),
                    const SizedBox(height: 32),

                    // Upload History
                    if (_uploadHistory.isNotEmpty)
                      _buildHistorySection(isDarkMode),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUploadSection(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_rounded,
                  size: 60,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload File',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CSV, XLSX, XLS, JSON, TXT',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Click to browse',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6366F1),
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

  Widget _buildFileInfo(bool isDarkMode) {
    final fileSize = _selectedFile!.lengthSync();
    final fileName = _selectedFile!.path.split('/').last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() => _selectedFile = null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBox(bool isDarkMode) {
    final Color boxColor;
    final IconData icon;

    if (_uploadStatus == 'success') {
      boxColor = const Color(0xFF10B981).withValues(alpha: 0.1);
      icon = Icons.check_circle_rounded;
    } else if (_uploadStatus == 'error') {
      boxColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
      icon = Icons.error_rounded;
    } else {
      boxColor = const Color(0xFF3B82F6).withValues(alpha: 0.1);
      icon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _uploadStatus == 'success'
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : _uploadStatus == 'error'
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : const Color(0xFF3B82F6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _uploadStatus == 'success'
                ? const Color(0xFF10B981)
                : _uploadStatus == 'error'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF3B82F6),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadMessage,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _uploadStatus == 'success'
                    ? const Color(0xFF10B981)
                    : _uploadStatus == 'error'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Download Templates',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildTemplateCard(isDarkMode, 'CSV Template', Icons.table_chart_rounded, () {}),
            _buildTemplateCard(isDarkMode, 'Excel Template', Icons.calculate_rounded, () {}),
            _buildTemplateCard(isDarkMode, 'JSON Template', Icons.data_object_rounded, () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateCard(
    bool isDarkMode,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload History',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _uploadHistory.length,
          itemBuilder: (context, index) {
            final item = _uploadHistory[index];
            return _buildHistoryItem(isDarkMode, item);
          },
        ),
      ],
    );
  }

  Widget _buildHistoryItem(bool isDarkMode, UploadHistory item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: item.status == 'success' ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Uploaded ${item.uploadTime.toString().split('.').first}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UploadHistory {
  final String fileName;
  final DateTime uploadTime;
  final String status;

  UploadHistory({
    required this.fileName,
    required this.uploadTime,
    required this.status,
  });
}
