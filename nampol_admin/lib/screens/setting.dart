import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('system_settings').doc('main').get();
      if (doc.exists) {
        setState(() {
          _settings.addAll(doc.data() ?? {});
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _firestore.collection('system_settings').doc('main').set(_settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingSwitch(
              'Maintenance Mode',
              'maintenance_mode',
              Icons.construction,
            ),
            _buildSettingSwitch(
              'User Registration',
              'allow_registration',
              Icons.person_add,
            ),
            _buildSettingSwitch(
              'Email Notifications',
              'email_notifications',
              Icons.email,
            ),
            _buildSettingTextField(
              'Session Timeout (mins)',
              'session_timeout',
              Icons.timer,
              keyboardType: TextInputType.number,
            ),
            _buildSettingTextField(
              'Data Backup Frequency',
              'backup_frequency',
              Icons.backup,
            ),
            _buildSettingDropdown(
              'Default Theme',
              'default_theme',
              Icons.color_lens,
              ['Light', 'Dark', 'System'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(String label, String key, IconData icon) {
    return SwitchListTile(
      title: Text(label),
      value: _settings[key] ?? false,
      secondary: Icon(icon),
      onChanged: (value) => setState(() => _settings[key] = value),
    );
  }

  Widget _buildSettingTextField(
      String label,
      String key,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return ListTile(
      leading: Icon(icon),
      title: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const UnderlineInputBorder(),
        ),
        keyboardType: keyboardType,
        controller: TextEditingController(text: _settings[key]?.toString() ?? ''),
        onChanged: (value) => _settings[key] = keyboardType == TextInputType.number
            ? int.tryParse(value)
            : value,
      ),
    );
  }

  Widget _buildSettingDropdown(
      String label,
      String key,
      IconData icon,
      List<String> options,
      ) {
    return ListTile(
      leading: Icon(icon),
      title: DropdownButtonFormField<String>(
        value: _settings[key]?.toString() ?? options.first,
        decoration: InputDecoration(
          labelText: label,
          border: const UnderlineInputBorder(),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (value) => setState(() => _settings[key] = value),
      ),
    );
  }
}