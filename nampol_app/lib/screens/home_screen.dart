import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nampol_app/screens/report_screen.dart';
import 'package:nampol_app/screens/reports_details_screen.dart';
import 'map_screen.dart';
import 'messaging_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late User? currentUser;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _refreshData() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Police Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MessagingScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.map),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _confirmLogout,
              ),
            ],
          ),
          body: _currentIndex == 0 ? _buildDashboard() : const ReportsPage(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: 'Reports',
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewIncidentReportScreen()),
            ),
            child: const Icon(Icons.add),
          )
              : null,
        );
      },
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOfficerProfile(),
            const SizedBox(height: 24),
            _buildStatisticsSection(),
            const SizedBox(height: 24),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficerProfile() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('officers')
          .doc(currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ));
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile Not Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Please contact administrator',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final officer = snapshot.data!;
        final status = officer['status'] ?? 'Available'; // Default status
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${officer['firstName']} ${officer['lastName']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${officer['rank']} • ${officer['department']}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        'Badge #${officer['badgeNumber']}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusIndicator(status),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _changeStatus,
                  tooltip: 'Change Status',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Busy':
        return Colors.orange;
      case 'Off-duty':
        return Colors.red;
      case 'In Pursuit':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusIndicator(String status) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: TextStyle(
            color: _getStatusColor(status),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _changeStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption('Available', Colors.green),
            _buildStatusOption('Busy', Colors.orange),
            _buildStatusOption('In Pursuit', Colors.purple),
            _buildStatusOption('Off-duty', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(String status, Color color) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(status),
      onTap: () {
        _updateOfficerStatus(status);
        Navigator.pop(context);
      },
    );
  }

  void _updateOfficerStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('officers')
          .doc(currentUser?.uid)
          .update({'status': status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatisticsSection() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfYesterday = DateTime(today.year, today.month, today.day - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Incident Statistics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildEnhancedStatCard(
              title: 'Today\'s Reports',
              icon: Icons.today,
              stream: FirebaseFirestore.instance
                  .collection('incident_reports')
                  .where('officerReport.timestamp', isGreaterThan: startOfToday)
                  .snapshots(),
              color: Colors.blue,
              previousStream: FirebaseFirestore.instance
                  .collection('incident_reports')
                  .where('officerReport.timestamp',
                  isGreaterThan: startOfYesterday,
                  isLessThan: startOfToday)
                  .snapshots(),
            ),
            _buildEnhancedStatCard(
              title: 'Your Cases',
              icon: Icons.assignment,
              stream: FirebaseFirestore.instance
                  .collection('incident_reports')
                  .where('officerReport.reportingOfficer.uid', isEqualTo: currentUser?.uid)
                  .snapshots(),
              color: Colors.green,
            ),
            _buildEnhancedStatCard(
              title: 'High Priority',
              icon: Icons.warning,
              stream: FirebaseFirestore.instance
                  .collection('incident_reports')
                  .where('caseInfo.severityLevel', whereIn: ['High', 'Critical'])
                  .snapshots(),
              color: Colors.red,
            ),
            _buildEnhancedStatCard(
              title: 'Pending Review',
              icon: Icons.pending,
              stream: FirebaseFirestore.instance
                  .collection('incident_reports')
                  .where('caseInfo.status', isEqualTo: 'Pending Approval')
                  .snapshots(),
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard({
    required String title,
    required IconData icon,
    required Stream<QuerySnapshot> stream,
    required Color color,
    Stream<QuerySnapshot>? previousStream,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return previousStream != null
            ? _buildStatCardWithTrend(title, icon, color, count, previousStream)
            : _buildSimpleStatCard(title, icon, color, count);
      },
    );
  }

  Widget _buildSimpleStatCard(String title, IconData icon, Color color, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  color: color.withOpacity(0.3),
                ),
                Icon(icon, size: 24, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardWithTrend(
      String title,
      IconData icon,
      Color color,
      int count,
      Stream<QuerySnapshot> previousStream
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: previousStream,
      builder: (context, previousSnapshot) {
        final previousCount = previousSnapshot.hasData ? previousSnapshot.data!.docs.length : 0;
        final bool isIncreasing = count > previousCount;
        final int difference = (count - previousCount).abs();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      color: color.withOpacity(0.3),
                    ),
                    Icon(icon, size: 24, color: color),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (previousCount > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isIncreasing ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$difference',
                        style: TextStyle(
                          fontSize: 10,
                          color: isIncreasing ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildActionCard(
              icon: Icons.map,
              label: 'Start Patrol',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              ),
              color: Colors.blue,
            ),
            _buildActionCard(
              icon: Icons.emergency,
              label: 'Emergency',
              onTap: _triggerEmergency,
              color: Colors.red,
            ),
            _buildActionCard(
              icon: Icons.people,
              label: 'Request Backup',
              onTap: _requestBackup,
              color: Colors.orange,
            ),
            _buildActionCard(
              icon: Icons.notifications,
              label: 'View Alerts',
              onTap: _viewAlerts,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerEmergency() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text('This will notify all nearby units and dispatch. Confirm emergency?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Send emergency to Firestore
        await FirebaseFirestore.instance.collection('emergencies').add({
          'officerId': currentUser?.uid,
          'officerName': '${currentUser?.displayName ?? "Unknown Officer"}',
          'timestamp': FieldValue.serverTimestamp(),
          'location': null, // You can add location here using GPS
          'status': 'active',
          'type': 'officer_emergency',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent! Help is on the way.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send emergency alert'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _requestBackup() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Backup'),
        content: const Text('Request assistance from nearby units?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance.collection('backup_requests').add({
          'officerId': currentUser?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup requested! Nearby units notified.'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to request backup'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AlertsScreen()),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}