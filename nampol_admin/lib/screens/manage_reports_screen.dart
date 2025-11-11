import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageReportsScreen extends StatefulWidget {
  const ManageReportsScreen({Key? key}) : super(key: key);

  @override
  State<ManageReportsScreen> createState() => _ManageReportsScreenState();
}

class _ManageReportsScreenState extends State<ManageReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _filterSeverity = 'All';
  String _sortField = 'timestamp';
  bool _sortDescending = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _statusNoteController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _statusNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Incident Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFiltersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search reports',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No reports found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final report = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final reportId = snapshot.data!.docs[index].id;
                    return _buildReportCard(report, reportId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredReports() {
    Query query = _firestore.collection('incident_reports')
        .orderBy('officerReport.$_sortField', descending: _sortDescending);

    if (_searchQuery.isNotEmpty) {
      query = query.where('caseInfo.caseNumber', isEqualTo: _searchQuery);
    }

    if (_filterStatus != 'All') {
      query = query.where('caseInfo.status', isEqualTo: _filterStatus);
    }

    if (_filterSeverity != 'All') {
      query = query.where('caseInfo.severityLevel', isEqualTo: _filterSeverity);
    }

    return query.snapshots();
  }

  Widget _buildReportCard(Map<String, dynamic> report, String reportId) {
    final caseInfo = report['caseInfo'] as Map<String, dynamic>;
    final officerReport = report['officerReport'] as Map<String, dynamic>;
    final dateTime = DateTime.parse(caseInfo['dateTime']);
    final status = caseInfo['status'] ?? 'Pending';
    final severity = caseInfo['severityLevel'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2.0,
      child: InkWell(
        onTap: () => _showReportDetails(report, reportId),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    caseInfo['caseNumber'] ?? 'No Case Number',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _getSeverityIcon(severity),
                    size: 16,
                    color: _getSeverityColor(severity),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${caseInfo['incidentType'] ?? 'Unknown Incident'} - $severity',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(caseInfo['location'] ?? 'No location'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${officerReport['reportingOfficer']['firstName']} '
                        '${officerReport['reportingOfficer']['lastName']}',
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showStatusChangeDialog(reportId, status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return ActionChip(
      label: Text(status),
      backgroundColor: _getStatusColor(status),
      onPressed: () {},
      avatar: Icon(
        _getStatusIcon(status),
        size: 16,
        color: _getStatusTextColor(status),
      ),
      labelStyle: TextStyle(
        color: _getStatusTextColor(status),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.withOpacity(0.2);
      case 'Approved':
        return Colors.green.withOpacity(0.2);
      case 'Rejected':
        return Colors.red.withOpacity(0.2);
      case 'Closed':
        return Colors.blue.withOpacity(0.2);
      case 'Under Review':
        return Colors.purple.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade800;
      case 'Approved':
        return Colors.green.shade800;
      case 'Rejected':
        return Colors.red.shade800;
      case 'Closed':
        return Colors.blue.shade800;
      case 'Under Review':
        return Colors.purple.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending;
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      case 'Closed':
        return Icons.lock;
      case 'Under Review':
        return Icons.visibility;
      default:
        return Icons.help_outline;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Icons.arrow_downward;
      case 'medium':
        return Icons.remove;
      case 'high':
        return Icons.arrow_upward;
      case 'critical':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _showReportDetails(Map<String, dynamic> report, String reportId) async {
    final caseInfo = report['caseInfo'] as Map<String, dynamic>;
    final officerReport = report['officerReport'] as Map<String, dynamic>;
    final dateTime = DateTime.parse(caseInfo['dateTime']);
    final status = caseInfo['status'] ?? 'Pending';
    final severity = caseInfo['severityLevel'] ?? 'Unknown';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report ${caseInfo['caseNumber']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(status),
                  Row(
                    children: [
                      Icon(
                        _getSeverityIcon(severity),
                        size: 16,
                        color: _getSeverityColor(severity),
                      ),
                      const SizedBox(width: 4),
                      Text(severity),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Type', caseInfo['incidentType']),
              _buildDetailRow('Location', caseInfo['location']),
              _buildDetailRow('Date/Time', DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime)),
              _buildDetailRow('Description', caseInfo['description']),
              const SizedBox(height: 16),
              const Text('Reporting Officer:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow(
                'Name',
                '${officerReport['reportingOfficer']['firstName']} '
                    '${officerReport['reportingOfficer']['lastName']}',
              ),
              _buildDetailRow('Badge', officerReport['reportingOfficer']['badgeNumber']),
              const SizedBox(height: 16),
              const Text('Officer Observations:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(officerReport['observations'] ?? 'N/A'),
              const SizedBox(height: 16),
              const Text('Actions Taken:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(officerReport['actionsTaken'] ?? 'N/A'),
              if (report['statusHistory'] != null) ...[
                const SizedBox(height: 16),
                const Text('Status History:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._buildStatusHistory(report['statusHistory']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _showStatusChangeDialog(reportId, status),
            child: const Text('Change Status'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusHistory(List<dynamic>? statusHistory) {
    if (statusHistory == null || statusHistory.isEmpty) {
      return [const Text('No status history available')];
    }

    return statusHistory.map((entry) {
      final data = entry as Map<String, dynamic>;
      return ListTile(
        leading: Icon(
          _getStatusIcon(data['status']),
          color: _getStatusTextColor(data['status']),
        ),
        title: Text(data['status']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By: ${data['changedBy'] ?? 'System'}'),
            Text('On: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(data['timestamp']))}'),
            if (data['note'] != null) Text('Note: ${data['note']}'),
          ],
        ),
      );
    }).toList();
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

  Future<void> _showStatusChangeDialog(String reportId, String currentStatus) async {
    _statusNoteController.clear();
    String? selectedStatus;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Report Status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select new status:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildStatusChoiceChip('Pending', currentStatus, selectedStatus, () {
                        setState(() => selectedStatus = 'Pending');
                      }),
                      _buildStatusChoiceChip('Under Review', currentStatus, selectedStatus, () {
                        setState(() => selectedStatus = 'Under Review');
                      }),
                      _buildStatusChoiceChip('Approved', currentStatus, selectedStatus, () {
                        setState(() => selectedStatus = 'Approved');
                      }),
                      _buildStatusChoiceChip('Rejected', currentStatus, selectedStatus, () {
                        setState(() => selectedStatus = 'Rejected');
                      }),
                      _buildStatusChoiceChip('Closed', currentStatus, selectedStatus, () {
                        setState(() => selectedStatus = 'Closed');
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _statusNoteController,
                    decoration: const InputDecoration(
                      labelText: 'Status Note (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: selectedStatus == null
                    ? null
                    : () async {
                  await _updateReportStatus(
                    reportId,
                    selectedStatus!,
                    _statusNoteController.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChoiceChip(
      String status,
      String currentStatus,
      String? selectedStatus,
      VoidCallback onSelected,
      ) {
    return ChoiceChip(
      label: Text(status),
      selected: selectedStatus == status || (selectedStatus == null && currentStatus == status),
      onSelected: (selected) => onSelected(),
      selectedColor: _getStatusColor(status),
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: selectedStatus == status || (selectedStatus == null && currentStatus == status)
            ? _getStatusTextColor(status)
            : Colors.black,
      ),
      avatar: Icon(
        _getStatusIcon(status),
        size: 16,
        color: selectedStatus == status || (selectedStatus == null && currentStatus == status)
            ? _getStatusTextColor(status)
            : Colors.grey,
      ),
    );
  }

  Future<void> _updateReportStatus(String reportId, String newStatus, String note) async {
    try {
      final user = _auth.currentUser;
      final statusUpdate = {
        'status': newStatus,
        'changedBy': user?.email ?? 'Admin',
        'timestamp': DateTime.now().toIso8601String(),
        if (note.isNotEmpty) 'note': note,
      };

      await _firestore.collection('incident_reports').doc(reportId).update({
        'caseInfo.status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
        'statusHistory': FieldValue.arrayUnion([statusUpdate]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _showFiltersDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Reports'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Under Review', child: Text('Under Review')),
                    DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                  ],
                  onChanged: (value) => setState(() => _filterStatus = value!),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _filterSeverity,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Severities')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                  ],
                  onChanged: (value) => setState(() => _filterSeverity = value!),
                  decoration: const InputDecoration(labelText: 'Severity'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterStatus = 'All';
                    _filterSeverity = 'All';
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

  Future<void> _showSortDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('Date (Newest First)'),
              value: 'timestamp',
              groupValue: _sortField,
              onChanged: (value) {
                setState(() {
                  _sortField = value.toString();
                  _sortDescending = true;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile(
              title: const Text('Date (Oldest First)'),
              value: 'timestamp',
              groupValue: _sortField,
              onChanged: (value) {
                setState(() {
                  _sortField = value.toString();
                  _sortDescending = false;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile(
              title: const Text('Case Number (A-Z)'),
              value: 'caseNumber',
              groupValue: _sortField,
              onChanged: (value) {
                setState(() {
                  _sortField = 'caseInfo.caseNumber';
                  _sortDescending = false;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile(
              title: const Text('Case Number (Z-A)'),
              value: 'caseNumber',
              groupValue: _sortField,
              onChanged: (value) {
                setState(() {
                  _sortField = 'caseInfo.caseNumber';
                  _sortDescending = true;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}