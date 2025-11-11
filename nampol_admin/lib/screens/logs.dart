import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({Key? key}) : super(key: key);

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _filterAction = 'All';
  String _filterUser = 'All';
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFiltersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search logs',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          _buildDateRangeChip(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredLogs(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data!.docs;

                if (logs.isEmpty) {
                  return const Center(child: Text('No logs found'));
                }

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    return _buildLogItem(log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          InputChip(
            label: Text(DateFormat('MMM d').format(_dateRange.start)),
            onPressed: _selectStartDate,
          ),
          const Text('to'),
          InputChip(
            label: Text(DateFormat('MMM d').format(_dateRange.end)),
            onPressed: _selectEndDate,
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredLogs() {
    Query query = _firestore.collection('audit_logs')
        .where('timestamp', isGreaterThanOrEqualTo: _dateRange.start)
        .where('timestamp', isLessThanOrEqualTo: _dateRange.end)
        .orderBy('timestamp', descending: true);

    if (_searchController.text.isNotEmpty) {
      query = query.where('searchKeywords', arrayContains: _searchController.text.toLowerCase());
    }

    if (_filterAction != 'All') {
      query = query.where('action', isEqualTo: _filterAction);
    }

    if (_filterUser != 'All') {
      query = query.where('userId', isEqualTo: _filterUser);
    }

    return query.snapshots();
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final timestamp = (log['timestamp'] as Timestamp).toDate();
    final action = log['action'] ?? 'Unknown Action';
    final userEmail = log['userEmail'] ?? 'System';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: _getActionIcon(action),
        title: Text(action),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userEmail),
            Text(DateFormat('MMM d, y - h:mm a').format(timestamp)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  Icon _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return const Icon(Icons.login, color: Colors.blue);
      case 'logout':
        return const Icon(Icons.logout, color: Colors.blue);
      case 'create':
        return const Icon(Icons.add, color: Colors.green);
      case 'update':
        return const Icon(Icons.edit, color: Colors.orange);
      case 'delete':
        return const Icon(Icons.delete, color: Colors.red);
      case 'permission change':
        return const Icon(Icons.lock, color: Colors.purple);
      default:
        return const Icon(Icons.history);
    }
  }

  Future<void> _showLogDetails(Map<String, dynamic> log) async {
    final timestamp = (log['timestamp'] as Timestamp).toDate();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log['action'] ?? 'Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('User', log['userEmail'] ?? 'System'),
              _buildDetailRow('Timestamp', DateFormat('MMM d, y - h:mm:ss a').format(timestamp)),
              _buildDetailRow('IP Address', log['ipAddress'] ?? 'N/A'),
              _buildDetailRow('User Agent', log['userAgent'] ?? 'N/A'),
              const SizedBox(height: 16),
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(log['details']?.toString() ?? 'No additional details'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateRange.start,
      firstDate: DateTime(2020),
      lastDate: _dateRange.end,
    );
    if (picked != null) {
      setState(() => _dateRange = DateTimeRange(
        start: picked,
        end: _dateRange.end,
      ));
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateRange.end,
      firstDate: _dateRange.start,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateRange = DateTimeRange(
        start: _dateRange.start,
        end: picked,
      ));
    }
  }

  Future<void> _showFiltersDialog() async {
    final users = await _firestore.collection('users').get();
    final userOptions = ['All', ...users.docs.map((doc) => doc['email']?.toString() ?? 'Unknown').toList()];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Logs'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _filterAction,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Actions')),
                      DropdownMenuItem(value: 'login', child: Text('Login')),
                      DropdownMenuItem(value: 'logout', child: Text('Logout')),
                      DropdownMenuItem(value: 'create', child: Text('Create')),
                      DropdownMenuItem(value: 'update', child: Text('Update')),
                      DropdownMenuItem(value: 'delete', child: Text('Delete')),
                      DropdownMenuItem(value: 'permission change', child: Text('Permission Change')),
                    ],
                    onChanged: (value) => setState(() => _filterAction = value!),
                    decoration: const InputDecoration(labelText: 'Action'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _filterUser,
                    items: userOptions.map((email) {
                      return DropdownMenuItem(
                        value: email == 'All' ? 'All' : email,
                        child: Text(email),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _filterUser = value!),
                    decoration: const InputDecoration(labelText: 'User'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterAction = 'All';
                    _filterUser = 'All';
                  });
                  Navigator.pop(context);
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }
}