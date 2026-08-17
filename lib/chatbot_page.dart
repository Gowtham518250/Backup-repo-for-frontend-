import 'package:flutter/material.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'ai_features_service.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'msg': 'Hello! I am your AI assistant. How can I help you today?', 'isMe': false},
  ];
  bool isTyping = false;
  
  @override
  void initState() {
    super.initState();
    _loadGreeting();
  }
  
  void _loadGreeting() async {
    final greeting = await ChatbotContextService.getPersonalizedGreeting();
    setState(() {
      _messages[0] = {'msg': greeting, 'isMe': false};
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add({'msg': text, 'isMe': true});
      _msgController.clear();
      isTyping = true;
    });

    try {
      final response = await ChatbotContextService.sendMessageWithContext(text);
      if (mounted) {
        setState(() {
          _messages.add({'msg': response, 'isMe': false});
          isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'msg': 'Error connecting to AI: $e', 'isMe': false});
          isTyping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Assistant', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: m['isMe'] ? const Color(0xFF6366F1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: m['isMe'] ? Radius.zero : const Radius.circular(16),
                        bottomLeft: m['isMe'] ? const Radius.circular(16) : Radius.zero,
                      ),
                    ),
                    child: Text(
                      m['msg'],
                      style: TextStyle(color: m['isMe'] ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('AI is typing...', style: TextStyle(fontSize: 10, color: Colors.grey))),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.1),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
