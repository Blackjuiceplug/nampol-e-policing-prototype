import 'package:flutter/material.dart';
import 'package:nampol_admin/screens/access_contrl.dart';
import 'package:nampol_admin/screens/analytics.dart';
import 'package:nampol_admin/screens/setting.dart';
import '../services/admin_page.dart';
import 'admin_messaging_screen.dart';
import 'logs.dart';
import 'manage_officers_screen.dart';
import 'manage_reports_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ADMIN DASHBOARD',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2
            )),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateAdminPage()),
            ),
          ),
          const SizedBox(width: 8)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Reduced padding from 24 to 16
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Administration Console',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87
                )),
            const SizedBox(height: 8),
            Text('Manage system operations and configurations',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600]
                )),
            const SizedBox(height: 24), // Reduced from 32 to 24
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.3, // Changed from 1.1 to make less square
                crossAxisSpacing: 16, // Reduced from 20 to 16
                mainAxisSpacing: 16, // Reduced from 20 to 16
                padding: const EdgeInsets.all(0), // Remove any extra padding
                children: [
                  _DashboardCard(
                    icon: Icons.people_alt_outlined,
                    title: 'Officer Management',
                    subtitle: 'View and manage officers',
                    color: const Color(0xFF4361EE),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageOfficersScreen()),
                    ),
                    compact: true, // Added compact mode
                  ),
                  _DashboardCard(
                    icon: Icons.assignment_outlined,
                    title: 'Report Management',
                    subtitle: 'Process incident reports',
                    color: const Color(0xFF3F37C9),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageReportsScreen()),
                    ),
                    compact: true, // Added compact mode
                  ),
                  _DashboardCard(
                    icon: Icons.message_outlined,
                    title: 'Officer Messaging',
                    subtitle: 'Communicate with officers',
                    color: const Color(0xFF3A86FF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminMessagingScreen()),
                    ),
                    compact: true,
                  ),
                  _DashboardCard(
                    icon: Icons.settings_outlined,
                    title: 'System Settings',
                    subtitle: 'Configure system parameters',
                    color: const Color(0xFF4895EF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SystemSettingsScreen()),
                    ),
                    compact: true, // Added compact mode
                  ),
                  _DashboardCard(
                    icon: Icons.analytics_outlined,
                    title: 'System Analytics',
                    subtitle: 'View performance metrics',
                    color: const Color(0xFF4CC9F0),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SimpleAnalyticsScreen()),
                    ),
                    compact: true, // Added compact mode
                  ),
                  _DashboardCard(
                    icon: Icons.lock_outline,
                    title: 'Access Control',
                    subtitle: 'Manage permissions',
                    color: const Color(0xFF7209B7),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AccessControlScreen()),
                    ),
                    compact: true, // Added compact mode
                  ),
                  _DashboardCard(
                    icon: Icons.history_outlined,
                    title: 'Audit Logs',
                    subtitle: 'View activity history',
                    color: const Color(0xFFF72585),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuditLogsScreen()),
                    ),
                    compact: true, // Added compact mode
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final bool compact;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
    this.compact = false, // Default to false for backward compatibility
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12, // Reduced from 20 to 12
                  offset: const Offset(0, 4)
              )
            ],
          ),
          child: Padding(
            padding: compact
                ? const EdgeInsets.all(12) // Reduced padding for compact mode
                : const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced from 12 to 8
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: Icon(icon,
                      size: compact ? 20 : 24, // Smaller icon in compact mode
                      color: color),
                ),
                const SizedBox(height: 12), // Reduced from 16 to 12
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: compact ? 14 : null, // Smaller text in compact mode
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: compact ? 12 : null, // Smaller text in compact mode
                    )),
                const Spacer(),
                Row(
                  children: [
                    Text('View',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 10 : null, // Smaller text in compact mode
                        )),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: compact ? 12 : 14, // Smaller icon in compact mode
                        color: color)
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}