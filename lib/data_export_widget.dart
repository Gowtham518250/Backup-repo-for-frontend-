import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'export_service.dart';

enum ExportTimeRange { today, last7Days, last30Days, thisYear, custom }

enum ExportFormat { excel, pdf, gstr1, tally }

class DataExportWidget extends StatefulWidget {
  final List<Map<String, dynamic>> allSales;
  final String shopName;
  final String? shopPhone;

  const DataExportWidget({
    super.key,
    required this.allSales,
    required this.shopName,
    this.shopPhone,
  });

  @override
  State<DataExportWidget> createState() => _DataExportWidgetState();
}

class _DataExportWidgetState extends State<DataExportWidget> {
  ExportTimeRange _selectedTimeRange = ExportTimeRange.today;
  ExportFormat _selectedFormat = ExportFormat.excel;
  bool _isExporting = false;
  String _statusMessage = '';
  bool _showSuccess = false;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  List<Map<String, dynamic>> _filterSalesByTimeRange(ExportTimeRange range) {
    if (widget.allSales.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (range) {
      case ExportTimeRange.today:
        startDate = today;
        break;
      case ExportTimeRange.last7Days:
        startDate = today.subtract(const Duration(days: 7));
        break;
      case ExportTimeRange.last30Days:
        startDate = today.subtract(const Duration(days: 30));
        break;
      case ExportTimeRange.thisYear:
        startDate = DateTime(now.year, 1, 1);
        break;
      case ExportTimeRange.custom:
        if (_customStartDate != null && _customEndDate != null) {
          startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
          endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
        } else {
          return widget.allSales;
        }
        break;
    }

    return widget.allSales.where((sale) {
      final saleDateStr = sale['date'] ?? sale['sale_date'] ?? DateTime.now().toIso8601String();
      final saleDate = _parseDate(saleDateStr);
      return !saleDate.isBefore(startDate) && !saleDate.isAfter(endDate);
    }).toList();
  }

  DateTime _parseDate(dynamic date) {
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Future<void> _performExport() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _statusMessage = 'Preparing export...';
      _showSuccess = false;
    });

    try {
      final filteredSales = _filterSalesByTimeRange(_selectedTimeRange);

      if (filteredSales.isEmpty) {
        setState(() {
          _statusMessage = '❌ No sales data for selected period';
          _isExporting = false;
        });
        return;
      }

      final totalRevenue = filteredSales.fold(0.0, (sum, sale) {
        final val = sale['total_with_tax'] ?? sale['total'] ?? 0;
        return sum + (double.tryParse(val.toString()) ?? 0.0);
      });

      String rangeLabel = _selectedTimeRange == ExportTimeRange.custom && _customStartDate != null && _customEndDate != null
          ? '${_customStartDate.toString().split(' ')[0]}_to_${_customEndDate.toString().split(' ')[0]}'
          : _selectedTimeRange.name;

      String? filePath;
      String? fileType;

      if (_selectedFormat == ExportFormat.excel) {
        setState(() => _statusMessage = 'Generating Excel (XLSX)...');
        final bytes = await ExportService.generateExcel(filteredSales);
        filePath = await ExportService.saveExcel(bytes,
            fileName:
                'sales_${rangeLabel}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
        fileType = 'Excel (XLSX)';
      } else if (_selectedFormat == ExportFormat.gstr1) {
        setState(() => _statusMessage = 'Generating GSTR-1 CSV...');
        final csv = await ExportService.generateGSTR1CSV(filteredSales);
        filePath = await ExportService.saveCSV(csv,
            fileName: 'GSTR1_${rangeLabel}_${DateTime.now().millisecondsSinceEpoch}.csv');
        fileType = 'GSTR-1 CSV';
      } else if (_selectedFormat == ExportFormat.tally) {
        setState(() => _statusMessage = 'Generating Tally Export...');
        final csv = await ExportService.generateTallyCSV(filteredSales);
        filePath = await ExportService.saveCSV(csv,
            fileName: 'TallySales_${rangeLabel}_${DateTime.now().millisecondsSinceEpoch}.csv');
        fileType = 'Tally CSV';
      } else {
        setState(() => _statusMessage = 'Generating PDF...');
        String dateRangeText = _selectedTimeRange == ExportTimeRange.custom && _customStartDate != null && _customEndDate != null
            ? '${_customStartDate.toString().split(' ')[0]} to ${_customEndDate.toString().split(' ')[0]}'
            : '${_selectedTimeRange.name.replaceAll('_', ' ').toUpperCase()} (${filteredSales.length} transactions)';

        filePath = await ExportService.savePDF(
          filteredSales,
          shopName: widget.shopName,
          shopPhone: widget.shopPhone,
          totalRevenue: '₹${totalRevenue.toStringAsFixed(2)}',
          dateRange: dateRangeText,
        );
        fileType = 'PDF';
      }

      if (filePath != null) {
        setState(() {
          _statusMessage = '✅ $fileType saved to Downloads!';
          _showSuccess = true;
        });

        // Immediately open share+open sheet so user can view the file
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          await ExportService.openWithShareSheet(filePath);
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}';
      });
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showShareDialog(String filePath, String fileType) {
    final filteredSales = _filterSalesByTimeRange(_selectedTimeRange);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ $fileType file has been saved'),
            const SizedBox(height: 8),
            Text('${filteredSales.length} transactions exported'),
            const SizedBox(height: 8),
            Text('File: ${filePath.split('/').last}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await Share.share('Export saved: ${File(filePath).path}');
              } catch (e) {
                print('Share error: $e');
              }
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSales = _filterSalesByTimeRange(_selectedTimeRange);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.download, color: Colors.blue.shade700, size: 26),
              const SizedBox(width: 12),
              Text(
                'Export Sales Data',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const Spacer(),
              if (_showSuccess)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Text(
                    '✓ Ready',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Time Range Selection
          Text(
            'Select Time Period:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TimeRangeChip(
                label: 'Today',
                range: ExportTimeRange.today,
                isSelected: _selectedTimeRange == ExportTimeRange.today,
                onTap: () => setState(() => _selectedTimeRange = ExportTimeRange.today),
              ),
              _TimeRangeChip(
                label: 'Last 7 Days',
                range: ExportTimeRange.last7Days,
                isSelected: _selectedTimeRange == ExportTimeRange.last7Days,
                onTap: () =>
                    setState(() => _selectedTimeRange = ExportTimeRange.last7Days),
              ),
              _TimeRangeChip(
                label: 'Last 30 Days',
                range: ExportTimeRange.last30Days,
                isSelected: _selectedTimeRange == ExportTimeRange.last30Days,
                onTap: () =>
                    setState(() => _selectedTimeRange = ExportTimeRange.last30Days),
              ),
              _TimeRangeChip(
                label: 'This Year',
                range: ExportTimeRange.thisYear,
                isSelected: _selectedTimeRange == ExportTimeRange.thisYear,
                onTap: () =>
                    setState(() => _selectedTimeRange = ExportTimeRange.thisYear),
              ),
              _TimeRangeChip(
                label: 'Custom Range',
                range: ExportTimeRange.custom,
                isSelected: _selectedTimeRange == ExportTimeRange.custom,
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _customStartDate != null && _customEndDate != null
                        ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
                        : null,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue.shade700,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _customStartDate = picked.start;
                      _customEndDate = picked.end;
                      _selectedTimeRange = ExportTimeRange.custom;
                    });
                  }
                },
              ),
            ],
          ),
          if (_selectedTimeRange == ExportTimeRange.custom && _customStartDate != null && _customEndDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Selected: ${_customStartDate.toString().split(' ')[0]} to ${_customEndDate.toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 16),

          // Format Selection
          Text(
            'Export Format:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FormatRadio(
                  label: '📊 Excel',
                  isSelected: _selectedFormat == ExportFormat.excel,
                  onTap: () => setState(() => _selectedFormat = ExportFormat.excel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormatRadio(
                  label: '📄 PDF',
                  isSelected: _selectedFormat == ExportFormat.pdf,
                  onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormatRadio(
                  label: '🏛️ GSTR-1',
                  isSelected: _selectedFormat == ExportFormat.gstr1,
                  onTap: () => setState(() => _selectedFormat = ExportFormat.gstr1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormatRadio(
                  label: '📘 Tally',
                  isSelected: _selectedFormat == ExportFormat.tally,
                  onTap: () => setState(() => _selectedFormat = ExportFormat.tally),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${filteredSales.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      'Transactions',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: Colors.blue.shade200),
                Column(
                  children: [
                    Text(
                      '₹${filteredSales.fold(0.0, (sum, sale) {
                        final val = sale['total_with_tax'] ?? sale['total'] ?? 0;
                        return sum + (double.tryParse(val.toString()) ?? 0.0);
                      }).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      'Total Revenue',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status & Export Button
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _showSuccess
                    ? Colors.green.shade50
                    : _statusMessage.contains('❌')
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showSuccess
                      ? Colors.green.shade300
                      : _statusMessage.contains('❌')
                          ? Colors.red.shade300
                          : Colors.blue.shade300,
                ),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showSuccess
                      ? Colors.green.shade700
                      : _statusMessage.contains('❌')
                          ? Colors.red.shade700
                          : Colors.blue.shade700,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _performExport,
              icon: _isExporting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _isExporting ? 'Exporting...' : 'Export Now',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blue.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeChip extends StatelessWidget {
  final String label;
  final ExportTimeRange range;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeRangeChip({
    required this.label,
    required this.range,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade600 : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.blue.shade600 : Colors.blue.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.blue.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatRadio extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatRadio({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue.shade500 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
