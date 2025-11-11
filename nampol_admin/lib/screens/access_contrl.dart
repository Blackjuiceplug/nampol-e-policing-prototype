import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({Key? key}) : super(key: key);

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewRole,
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
                labelText: 'Search roles or users',
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
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Roles'),
                      Tab(text: 'Users'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRolesTab(),
                        _buildUsersTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('roles').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final roles = snapshot.data!.docs.where((doc) {
          final name = doc['name']?.toString().toLowerCase() ?? '';
          return name.contains(_searchController.text.toLowerCase());
        }).toList();

        return ListView.builder(
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ListTile(
                title: Text(role['name'] ?? 'Unnamed Role'),
                subtitle: Text('${role['users']?.length ?? 0} users'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _editRole(role),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.where((doc) {
          final email = doc['email']?.toString().toLowerCase() ?? '';
          final name = doc['displayName']?.toString().toLowerCase() ?? '';
          final searchTerm = _searchController.text.toLowerCase();
          return email.contains(searchTerm) || name.contains(searchTerm);
        }).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(user['displayName']?.toString().substring(0, 1) ?? '?'),
                ),
                title: Text(user['displayName'] ?? 'No Name'),
                subtitle: Text(user['email'] ?? 'No Email'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _editUserPermissions(user),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addNewRole() async {
    final nameController = TextEditingController();
    final permissions = <String, bool>{};

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Role'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              const SizedBox(height: 16),
              const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._buildPermissionSwitches(permissions),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              try {
                await _firestore.collection('roles').add({
                  'name': nameController.text,
                  'permissions': permissions,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating role: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPermissionSwitches(Map<String, bool> permissions) {
    const permissionOptions = [
      'manage_users',
      'manage_reports',
      'manage_settings',
      'view_analytics',
      'edit_content',
    ];

    return permissionOptions.map((permission) {
      return SwitchListTile(
        title: Text(permission.replaceAll('_', ' ')),
        value: permissions[permission] ?? false,
        onChanged: (value) => permissions[permission] = value,
      );
    }).toList();
  }

  Future<void> _editRole(QueryDocumentSnapshot role) async {
    final nameController = TextEditingController(text: role['name']);
    final permissions = Map<String, bool>.from(role['permissions'] ?? {});

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Role'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Role Name'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._buildPermissionSwitches(permissions),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await role.reference.update({
                      'name': nameController.text,
                      'permissions': permissions,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating role: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editUserPermissions(QueryDocumentSnapshot user) async {
    final rolesSnapshot = await _firestore.collection('roles').get();
    final roles = rolesSnapshot.docs;
    final userRoles = List<String>.from(user['roles'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit ${user['displayName']} Permissions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Assigned Roles:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...roles.map((role) {
                    final roleName = role['name'] ?? 'Unnamed Role';
                    final isAssigned = userRoles.contains(role.id);
                    return CheckboxListTile(
                      title: Text(roleName),
                      value: isAssigned,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            userRoles.add(role.id);
                          } else {
                            userRoles.remove(role.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await user.reference.update({
                      'roles': userRoles,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating user: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}