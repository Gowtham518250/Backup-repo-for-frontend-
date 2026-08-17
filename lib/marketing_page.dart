import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

class MarketingPage extends StatefulWidget {
  const MarketingPage({super.key});

  @override
  State<MarketingPage> createState() => _MarketingPageState();
}

class _MarketingPageState extends State<MarketingPage> {
  bool _isLoading = true;
  List<dynamic> _opportunities = [];

  @override
  void initState() {
    super.initState();
    _fetchRemarketing();
  }

  Future<void> _fetchRemarketing() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getJson('${ApiClient.remarketing}?threshold_days=30');
      if (response.statusCode == 200) {
        setState(() {
          _opportunities = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch remarketing opportunities: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendWhatsAppMessage(String phone, String text) async {
    // Sanitize phone number (e.g., ensure it starts with country code, no spaces)
    String sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!sanitized.startsWith('+')) {
      sanitized = '+91$sanitized'; // Defaulting to India if no code
    }
    final encodedText = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?phone=$sanitized&text=$encodedText');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp. Is it installed?')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Smart Remarketing',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchRemarketing,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _opportunities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_graph_rounded, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No dormant customers found.',
                        style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500]),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _opportunities.length,
                  itemBuilder: (context, index) {
                    final opp = _opportunities[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[50],
                                      child: Text(
                                        opp['name']?.substring(0, 1).toUpperCase() ?? 'C',
                                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          opp['name'] ?? 'Customer',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Last seen: ${opp['days_since_last_purchase']} days ago',
                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.red[400]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star, size: 16, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Favorite: ${opp['favorite_item']}',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    opp['suggested_message'] ?? '',
                                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _sendWhatsAppMessage(opp['phone'], opp['suggested_message']),
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text('Send WhatsApp Discount'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
