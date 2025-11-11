import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageOfficersScreen extends StatefulWidget {
  const ManageOfficersScreen({Key? key}) : super(key: key);

  @override
  State<ManageOfficersScreen> createState() => _ManageOfficersScreenState();
}

class _ManageOfficersScreenState extends State<ManageOfficersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _filterDepartment = 'All';
  String _sortField = 'createdAt';
  bool _sortDescending = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _blockReasonController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _blockReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Officers'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddOfficer,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search officers',
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
              stream: _getFilteredOfficers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No officers found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final officer = doc.data() as Map<String, dynamic>;
                    final officerId = doc.id;
                    return _buildOfficerCard(officer, officerId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredOfficers() {
    Query query = _firestore.collection('officers')
        .orderBy(_sortField, descending: _sortDescending);

    if (_searchQuery.isNotEmpty) {
      query = query.where('searchKeywords', arrayContains: _searchQuery.toLowerCase());
    }

    if (_filterStatus != 'All') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    if (_filterDepartment != 'All') {
      query = query.where('department', isEqualTo: _filterDepartment);
    }

    return query.snapshots();
  }

  Widget _buildOfficerCard(Map<String, dynamic> officer, String officerId) {
    final firstName = officer['firstName']?.toString() ?? 'Unknown';
    final lastName = officer['lastName']?.toString() ?? 'Officer';
    final email = officer['email']?.toString() ?? 'No email';
    final department = officer['department']?.toString() ?? 'No department';
    final rank = officer['rank']?.toString() ?? 'No rank';
    final status = officer['status']?.toString() ?? 'pending';
    final isApproved = officer['isApproved'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text('${firstName[0]}${lastName[0]}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$firstName $lastName', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('$rank - $department'),
                    ],
                  ),
                ),
                Switch(
                  value: isApproved,
                  onChanged: (value) => _updateApprovalStatus(officerId, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(email),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status: ${status.toUpperCase()}'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editOfficer(officerId, officer),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteOfficer(officerId),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateApprovalStatus(String officerId, bool isApproved) async {
    try {
      await _firestore.collection('officers').doc(officerId).update({
        'isApproved': isApproved,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': isApproved ? 'active' : 'pending',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating approval status: $e')),
      );
    }
  }

  Future<void> _editOfficer(String officerId, Map<String, dynamic> officer) async {
    final firstNameController = TextEditingController(text: officer['firstName']);
    final lastNameController = TextEditingController(text: officer['lastName']);
    final badgeController = TextEditingController(text: officer['badgeNumber']);
    final emailController = TextEditingController(text: officer['email']);
    final departmentController = TextEditingController(text: officer['department']);
    final rankController = TextEditingController(text: officer['rank']);

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Officer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextFormField(
                controller: badgeController,
                decoration: const InputDecoration(labelText: 'Badge Number'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              TextFormField(
                controller: rankController,
                decoration: const InputDecoration(labelText: 'Rank'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _firestore.collection('officers').doc(officerId).update({
          'firstName': firstNameController.text,
          'lastName': lastNameController.text,
          'badgeNumber': badgeController.text,
          'email': emailController.text,
          'department': departmentController.text,
          'rank': rankController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Officer updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating officer: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteOfficer(String officerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this officer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('officers').doc(officerId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Officer deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting officer: $e')),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddOfficer() async {
    // TODO: Implement navigation to add officer screen
  }

  Future<void> _showFiltersDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Officers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  ],
                  onChanged: (value) => setState(() => _filterStatus = value!),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _filterDepartment,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Departments')),
                    DropdownMenuItem(value: 'SWAT', child: Text('SWAT')),
                    // Add other departments as needed
                  ],
                  onChanged: (value) => setState(() => _filterDepartment = value!),
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterStatus = 'All';
                    _filterDepartment = 'All';
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
        title: const Text('Sort Officers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('Recently Added'),
              value: 'createdAt',
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
              title: const Text('Oldest First'),
              value: 'createdAt',
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
              title: const Text('Name (A-Z)'),
              value: 'lastName',
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
              title: const Text('Name (Z-A)'),
              value: 'lastName',
              groupValue: _sortField,
              onChanged: (value) {
                setState(() {
                  _sortField = value.toString();
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