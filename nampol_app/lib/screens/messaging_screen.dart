import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  String? _selectedConversationId;
  List<String> _participants = [];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkUserRole() async {
    try {
      final userDoc = await _firestore.collection('admins').doc(_currentUser?.uid).get();
      final isAdmin = userDoc.exists;

      setState(() {
        if (isAdmin) {
          _participants = [];
        } else {
          _participants = [_currentUser?.uid ?? '', 'admin'];
        }
      });
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await _firestore.collection('messages').add({
        'text': message,
        'senderId': _currentUser.uid,
        'senderName': _currentUser.email ?? 'Unknown',
        'participants': _participants.isNotEmpty
            ? _participants
            : [_currentUser.uid, _selectedConversationId ?? 'admin'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_participants.isEmpty) _buildUserSelector(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _participants.isNotEmpty
                  ? _firestore
                  .collection('messages')
                  .where('participants', arrayContains: _currentUser?.uid)
                  .orderBy('timestamp', descending: false)
                  .snapshots()
                  : _selectedConversationId != null
                  ? _firestore
                  .collection('messages')
                  .where('participants', arrayContains: _currentUser?.uid)
                  .where('participants', arrayContains: _selectedConversationId)
                  .orderBy('timestamp', descending: false)
                  .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['senderId'] == _currentUser?.uid;
                    final timestamp = message['timestamp'] as Timestamp?;

                    // Skip messages with null timestamp
                    if (timestamp == null) return const SizedBox.shrink();

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).primaryColor.withOpacity(0.8)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                message['senderName']?.toString() ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            Text(
                              message['text']?.toString() ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildUserSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('officers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Error loading officers');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }

          final officers = snapshot.data?.docs ?? [];

          return DropdownButtonFormField<String>(
            value: _selectedConversationId,
            decoration: InputDecoration(
              labelText: 'Select Officer',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Select an officer'),
              ),
              ...officers.map((officer) {
                return DropdownMenuItem<String>(
                  value: officer.id,
                  child: Text('${officer['firstName']} ${officer['lastName']}'),
                );
              }).toList(),
            ],
            onChanged: (value) => setState(() {
              _selectedConversationId = value;
              _participants = value != null
                  ? [_currentUser?.uid ?? '', value]
                  : [];
            }),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    try {
      final dateTime = timestamp.toDate();
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      debugPrint('Error formatting timestamp: $e');
      return '';
    }
  }
}