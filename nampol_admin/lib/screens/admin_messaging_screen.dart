import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminMessagingScreen extends StatefulWidget {
  const AdminMessagingScreen({super.key});

  @override
  State<AdminMessagingScreen> createState() => _AdminMessagingScreenState();
}

class _AdminMessagingScreenState extends State<AdminMessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  String? _selectedOfficerId;
  List<DocumentSnapshot> _officers = [];
  bool _isLoadingOfficers = true;

  @override
  void initState() {
    super.initState();
    _loadOfficers();
  }

  Future<void> _loadOfficers() async {
    setState(() => _isLoadingOfficers = true);
    try {
      final querySnapshot = await _firestore.collection('officers').get();
      setState(() {
        _officers = querySnapshot.docs;
        if (_officers.isNotEmpty) {
          _selectedOfficerId = _officers.first.id;
          _markMessagesAsRead(); // Mark messages as read when loading first officer
        }
      });
    } catch (e) {
      debugPrint('Error loading officers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load officers: $e')),
      );
    } finally {
      setState(() => _isLoadingOfficers = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedOfficerId == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await _firestore.collection('messages').add({
        'text': message,
        'senderId': _currentUser?.uid ?? 'admin',
        'senderName': 'Admin',
        'participants': [_currentUser?.uid ?? 'admin', _selectedOfficerId],
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

  Future<void> _markMessagesAsRead() async {
    if (_selectedOfficerId == null) return;

    try {
      final unreadMessages = await _firestore
          .collection('messages')
          .where('participants', arrayContains: _selectedOfficerId)
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: _currentUser?.uid ?? 'admin')
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
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

  Stream<QuerySnapshot> get _messagesStream {
    if (_selectedOfficerId == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _firestore
        .collection('messages')
        .where('participants', arrayContainsAny: [_currentUser?.uid ?? 'admin', _selectedOfficerId])
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Communications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfficers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOfficerSelector(),
          Expanded(
            child: _isLoadingOfficers
                ? const Center(child: CircularProgressIndicator())
                : _selectedOfficerId == null
                ? const Center(child: Text('No officers available'))
                : StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMessages = snapshot.data?.docs ?? [];
                final conversationMessages = allMessages.where((message) {
                  final participants = List<String>.from(message['participants'] ?? []);
                  return participants.contains(_selectedOfficerId) &&
                      (participants.contains(_currentUser?.uid) || participants.contains('admin'));
                }).toList();

                if (conversationMessages.isEmpty) {
                  return const Center(child: Text('No messages yet. Start the conversation!'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: conversationMessages.length,
                  itemBuilder: (context, index) {
                    final message = conversationMessages[index];
                    final isAdmin = message['senderId'] == _currentUser?.uid || message['senderId'] == 'admin';
                    final timestamp = message['timestamp'] as Timestamp?;
                    if (timestamp == null) return const SizedBox.shrink();

                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Theme.of(context).primaryColor.withOpacity(0.8)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isAdmin)
                              FutureBuilder<DocumentSnapshot>(
                                future: _firestore.collection('officers').doc(message['senderId']).get(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final officer = snapshot.data!;
                                    return Text(
                                      '${officer['firstName']} ${officer['lastName']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isAdmin ? Colors.white : Colors.black,
                                      ),
                                    );
                                  }
                                  return Text(
                                    message['senderName']?.toString() ?? 'Officer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isAdmin ? Colors.white : Colors.black,
                                    ),
                                  );
                                },
                              ),
                            Text(
                              message['text']?.toString() ?? '',
                              style: TextStyle(
                                color: isAdmin ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('h:mm a').format(timestamp.toDate()),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isAdmin ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                                if (isAdmin && message['isRead'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.done_all, size: 12, color: Colors.white70),
                                  ),
                              ],
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

  Widget _buildOfficerSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedOfficerId,
        decoration: InputDecoration(
          labelText: 'Select Officer',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        items: _officers.map((officer) {
          return DropdownMenuItem<String>(
            value: officer.id,
            child: Text('${officer['firstName']} ${officer['lastName']}'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedOfficerId = value);
          _markMessagesAsRead();
          _scrollToBottom();
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).scaffoldBackgroundColor,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
}