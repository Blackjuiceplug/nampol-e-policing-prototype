import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('incident_reports')
          .orderBy('officerReport.timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        if (reports.isEmpty) {
          return const Center(child: Text('No reports available'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;
            final caseInfo = data['caseInfo'] as Map<String, dynamic>;
            final officerReport = data['officerReport'] as Map<String, dynamic>;
            final timestamp = (officerReport['timestamp'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: _getReportIcon(caseInfo['incidentType']),
                title: Text(caseInfo['incidentType']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Case #${report.id.substring(0, 8)}'),
                    Text(DateFormat('MMM d, yyyy - h:mm a').format(timestamp)),
                  ],
                ),
                trailing: Chip(
                  label: Text(caseInfo['status']),
                  backgroundColor: _getStatusColor(caseInfo['status']),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportDetailsScreen(
                      reportId: report.id,
                      reportData: data,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Icon _getReportIcon(String incidentType) {
    switch (incidentType) {
      case 'Traffic Collision':
        return const Icon(Icons.car_crash, color: Colors.orange);
      case 'Burglary':
        return const Icon(Icons.home_work, color: Colors.blue);
      case 'Assault':
        return const Icon(Icons.medical_services, color: Colors.red);
      default:
        return const Icon(Icons.assignment, color: Colors.grey);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending Approval':
        return Colors.orange.withOpacity(0.2);
      case 'Under Investigation':
        return Colors.blue.withOpacity(0.2);
      case 'Completed':
        return Colors.green.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }
}

class ReportDetailsScreen extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const ReportDetailsScreen({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  @override
  Widget build(BuildContext context) {
    final caseInfo = reportData['caseInfo'] as Map<String, dynamic>;
    final officerReport = reportData['officerReport'] as Map<String, dynamic>;
    final personsInvolved = reportData['personsInvolved'] as Map<String, dynamic>;
    final timestamp = (officerReport['timestamp'] as Timestamp).toDate();

    return Scaffold(
      appBar: AppBar(
        title: Text('Case #${reportId.substring(0, 8)}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailSection(
              title: 'Incident Details',
              children: [
                _buildDetailItem('Type', caseInfo['incidentType']),
                _buildDetailItem('Location', caseInfo['location']),
                _buildDetailItem('Date', DateFormat('MMM d, yyyy - h:mm a').format(timestamp)),
                _buildDetailItem('Status', caseInfo['status']),
                _buildDetailItem('Severity', caseInfo['severityLevel']),
                const SizedBox(height: 8),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(caseInfo['description']),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              title: 'Suspect Information',
              children: [
                _buildDetailItem('Name', personsInvolved['suspect']['name']),
                _buildDetailItem('Description', personsInvolved['suspect']['description']),
                _buildDetailItem('Contact', personsInvolved['suspect']['contact']),
                _buildDetailItem('Last Seen', personsInvolved['suspect']['lastSeen']),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              title: 'Officer Report',
              children: [
                _buildDetailItem('Reporting Officer',
                    '${officerReport['reportingOfficer']['firstName']} ${officerReport['reportingOfficer']['lastName']}'),
                _buildDetailItem('Badge #', officerReport['reportingOfficer']['badgeNumber']),
                _buildDetailItem('Department', officerReport['reportingOfficer']['department']),
                const SizedBox(height: 8),
                const Text('Observations:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(officerReport['observations']),
                const SizedBox(height: 8),
                const Text('Actions Taken:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(officerReport['actionsTaken']),
              ],
            ),
            if (caseInfo['attachments'] != null && (caseInfo['attachments'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetailSection(
                title: 'Attachments',
                children: [
                  Wrap(
                    spacing: 8,
                    children: (caseInfo['attachments'] as List).map((url) =>
                        Chip(
                          label: Text(url.split('/').last),
                          onDeleted: () {}, // Implement view attachment
                        ),
                    ).toList(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value ?? 'Not specified')),
        ],
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!.docs;
          if (alerts.isEmpty) {
            return const Center(child: Text('No alerts available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final data = alert.data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: Icon(
                    _getAlertIcon(data['type']),
                    color: _getAlertColor(data['priority']),
                  ),
                  title: Text(data['title']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description']),
                      Text(DateFormat('MMM d, yyyy - h:mm a').format(timestamp)),
                    ],
                  ),
                  trailing: Text(
                    data['priority'],
                    style: TextStyle(
                      color: _getAlertColor(data['priority']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return Icons.warning;
      case 'notice':
        return Icons.notifications;
      case 'update':
        return Icons.system_update;
      default:
        return Icons.info;
    }
  }

  Color _getAlertColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}