import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class NewIncidentReportScreen extends StatefulWidget {
  const NewIncidentReportScreen({Key? key}) : super(key: key);

  @override
  State<NewIncidentReportScreen> createState() => _NewIncidentReportScreenState();
}

class _NewIncidentReportScreenState extends State<NewIncidentReportScreen> {
  // Firebase services
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _caseNumberController = TextEditingController();
  final _incidentTypeController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _suspectNameController = TextEditingController();
  final _suspectDescriptionController = TextEditingController();
  final _suspectContactController = TextEditingController();
  final _suspectLastSeenController = TextEditingController();
  final _officerObservationsController = TextEditingController();
  final _actionsTakenController = TextEditingController();
  final List<Map<String, TextEditingController>> _witnessControllers = [];

  // State variables
  final List<String> _attachmentPaths = [];
  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;
  String _severityLevel = 'Medium';
  Position? _currentPosition;
  bool _isOnline = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _pendingReports = [];
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _caseNumberController.dispose();
    _incidentTypeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _suspectNameController.dispose();
    _suspectDescriptionController.dispose();
    _suspectContactController.dispose();
    _suspectLastSeenController.dispose();
    for (var witness in _witnessControllers) {
      witness['name']?.dispose();
      witness['contact']?.dispose();
      witness['statement']?.dispose();
    }
    _officerObservationsController.dispose();
    _actionsTakenController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _checkConnectivity();
    _caseNumberController.text = _generateCaseNumber();
    _incidentDate = DateTime.now();
    _incidentTime = TimeOfDay.now();
    await _getCurrentLocation();
    await _loadPendingReports();

    // Set up connectivity listener
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
        if (_isOnline && _pendingReports.isNotEmpty) {
          _syncPendingReports();
        }
      }
    }) as StreamSubscription<ConnectivityResult>?;
  }

  Future<void> _loadPendingReports() async {
    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      final pendingReportsFile = File('${appDocumentDir.path}/pending_reports.json');

      if (await pendingReportsFile.exists()) {
        final contents = await pendingReportsFile.readAsString();
        if (contents.isNotEmpty) {
          final decoded = json.decode(contents);
          if (decoded is List) {
            setState(() {
              _pendingReports = List<Map<String, dynamic>>.from(decoded);
            });

            // Auto-sync if we have pending reports and are online
            if (_isOnline && _pendingReports.isNotEmpty) {
              _syncPendingReports();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading pending reports: $e');
    }
  }

  Future<void> _savePendingReports() async {
    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      final pendingReportsFile = File('${appDocumentDir.path}/pending_reports.json');

      await pendingReportsFile.writeAsString(json.encode(_pendingReports));
    } catch (e) {
      debugPrint('Error saving pending reports: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() => _isOnline = connectivityResult != ConnectivityResult.none);

    // Sync immediately if we're online and have pending reports
    if (_isOnline && _pendingReports.isNotEmpty) {
      _syncPendingReports();
    }
  }

  String _generateCaseNumber() {
    final now = DateTime.now();
    return 'CR-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = position);
        _locationController.text = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _incidentTime ?? TimeOfDay.now(),
    );
    if (time == null) return;

    if (mounted) {
      setState(() {
        _incidentDate = date;
        _incidentTime = time;
      });
    }
  }

  Future<void> _addAttachment() async {
    try {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }

      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (image == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');

      if (mounted) {
        setState(() => _attachmentPaths.add(savedImage.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add attachment: ${e.toString()}')),
        );
      }
    }
  }

  void _addWitnessField() {
    setState(() {
      _witnessControllers.add({
        'name': TextEditingController(),
        'contact': TextEditingController(),
        'statement': TextEditingController(),
      });
    });
  }

  void _removeWitnessField(int index) {
    setState(() {
      for (var controller in _witnessControllers[index].values) {
        controller.dispose();
      }
      _witnessControllers.removeAt(index);
    });
  }

  Future<List<String>> _uploadAttachments({List<String>? paths}) async {
    final filesToUpload = paths ?? _attachmentPaths;
    final List<String> downloadUrls = [];

    try {
      for (final filePath in filesToUpload) {
        final file = File(filePath);
        if (!await file.exists()) continue;

        final fileName = path.basename(filePath);
        final ref = _storage.ref()
            .child('incident_reports')
            .child(_caseNumberController.text)
            .child(fileName);

        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      }
    } catch (e) {
      debugPrint('Error uploading attachments: $e');
      rethrow;
    }

    return downloadUrls;
  }

  Future<void> _saveOffline(Map<String, dynamic> reportData) async {
    final appDir = await getApplicationDocumentsDirectory();
    final persistentPaths = <String>[];

    for (final path in _attachmentPaths) {
      final file = File(path);
      if (await file.exists()) {
        final newPath = '${appDir.path}/${path.split('/').last}';
        await file.copy(newPath);
        persistentPaths.add(newPath);
      }
    }

    final localReport = {
      ...reportData,
      'localId': DateTime.now().millisecondsSinceEpoch.toString(),
      'isSynced': false,
      'timestamp': DateTime.now().toIso8601String(),
      'caseInfo': {
        ...reportData['caseInfo'],
        'attachmentPaths': persistentPaths,
      },
    };

    setState(() {
      _pendingReports.add(localReport);
    });

    await _savePendingReports();
  }

  Future<void> _submitToFirestore(Map<String, dynamic> reportData) async {
    try {
      await _firestore.collection('incident_reports').add(reportData);
    } catch (e) {
      debugPrint('Error submitting to Firestore: $e');
      rethrow;
    }
  }

  Future<void> _syncPendingReports() async {
    if (_pendingReports.isEmpty) return;

    try {
      // Create a copy to avoid modification during iteration
      final reportsToSync = List<Map<String, dynamic>>.from(_pendingReports);
      final successfulSyncs = <String>[];

      for (final report in reportsToSync) {
        try {
          debugPrint('Syncing report: ${report['localId']}');

          // Upload attachments if they exist
          if (report['caseInfo']?['attachmentPaths'] != null) {
            final paths = List<String>.from(report['caseInfo']['attachmentPaths']);
            final urls = await _uploadAttachments(paths: paths);
            report['caseInfo']['attachments'] = urls;
            report['caseInfo'].remove('attachmentPaths');

            // Clean up local attachment files
            for (final path in paths) {
              try {
                final file = File(path);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (e) {
                debugPrint('Error deleting attachment file: $e');
              }
            }
          }

          // Submit to Firestore
          await _submitToFirestore(report);
          successfulSyncs.add(report['localId']);

          debugPrint('Successfully synced report: ${report['localId']}');

        } catch (e) {
          debugPrint('Failed to sync report ${report['localId']}: $e');
          // Continue with next report instead of stopping
          continue;
        }
      }

      // Remove successfully synced reports
      if (successfulSyncs.isNotEmpty) {
        setState(() {
          _pendingReports.removeWhere((report) => successfulSyncs.contains(report['localId']));
        });
        await _savePendingReports();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synced ${successfulSyncs.length} reports successfully.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint('Error in sync process: $e');
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    // Double-check connectivity before submitting
    final currentConnectivity = await Connectivity().checkConnectivity();
    final isCurrentlyOnline = currentConnectivity != ConnectivityResult.none;

    if (!isCurrentlyOnline) {
      // Show alert dialog for offline mode
      final shouldSaveOffline = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Internet Connection'),
          content: const Text('You are currently offline. Would you like to save this report locally and submit it when you regain connection?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Offline'),
            ),
          ],
        ),
      );

      if (shouldSaveOffline != true) {
        return; // User cancelled
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final officerDoc = await _firestore
          .collection('officers')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!officerDoc.exists) {
        throw Exception('Officer record not found');
      }

      final reportData = {
        'caseInfo': {
          'caseNumber': _caseNumberController.text,
          'incidentType': _incidentTypeController.text,
          'location': _locationController.text,
          'geoLocation': _currentPosition != null
              ? GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          )
              : null,
          'dateTime': DateTime(
            _incidentDate!.year,
            _incidentDate!.month,
            _incidentDate!.day,
            _incidentTime!.hour,
            _incidentTime!.minute,
          ).toIso8601String(),
          'description': _descriptionController.text,
          'severityLevel': _severityLevel,
          'status': 'Draft',
        },
        'personsInvolved': {
          'suspect': {
            'name': _suspectNameController.text,
            'description': _suspectDescriptionController.text,
            'contact': _suspectContactController.text,
            'lastSeen': _suspectLastSeenController.text,
          },
          'witnesses': _witnessControllers.map((witness) => {
            'name': witness['name']!.text,
            'contact': witness['contact']!.text,
            'statement': witness['statement']!.text,
          }).toList(),
        },
        'officerReport': {
          'observations': _officerObservationsController.text,
          'actionsTaken': _actionsTakenController.text,
          'reportingOfficer': {
            'uid': user.uid,
            'badgeNumber': officerDoc['badgeNumber'] ?? 'N/A',
            'firstName': officerDoc['firstName'] ?? '',
            'lastName': officerDoc['lastName'] ?? '',
            'email': officerDoc['email'] ?? user.email ?? '',
            'rank': officerDoc['rank'] ?? 'N/A',
            'department': officerDoc['department'] ?? 'N/A',
            'createdAt': officerDoc['createdAt'] ?? FieldValue.serverTimestamp(),
          },
          'timestamp': FieldValue.serverTimestamp(),
        },
      };

      if (isCurrentlyOnline) {
        try {
          if (_attachmentPaths.isNotEmpty) {
            final attachmentUrls = await _uploadAttachments()
                .timeout(const Duration(seconds: 30));
            reportData['caseInfo']!['attachments'] = attachmentUrls;
          }
          await _submitToFirestore(reportData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report submitted successfully'),
                duration: Duration(seconds: 3),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.of(context).pop();
          }
        } catch (e) {
          // If online submission fails, offer to save offline
          final shouldSaveOffline = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Submission Failed'),
              content: Text('Failed to submit report online: ${e.toString()}. Would you like to save it offline instead?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save Offline'),
                ),
              ],
            ),
          );

          if (shouldSaveOffline == true) {
            reportData['caseInfo']!['attachmentPaths'] = _attachmentPaths;
            await _saveOffline(reportData);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report saved offline. It will sync when connection is restored.'),
                  duration: Duration(seconds: 3),
                ),
              );
              Navigator.of(context).pop();
            }
          } else {
            rethrow; // Re-throw the error if user doesn't want to save offline
          }
        }
      } else {
        // Offline mode
        reportData['caseInfo']!['attachmentPaths'] = _attachmentPaths;
        await _saveOffline(reportData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report saved offline. It will sync when connection is restored.'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Error submitting report: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Incident Report'),
        actions: [
          IconButton(
            icon: _isSubmitting
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            )
                : const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitReport,
            tooltip: 'Submit Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.amber,
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, size: 20),
                      SizedBox(width: 8),
                      Text('OFFLINE MODE - Reports will be saved locally'),
                    ],
                  ),
                ),
              if (_pendingReports.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue,
                  child: Row(
                    children: [
                      const Icon(Icons.info, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '${_pendingReports.length} report(s) pending sync',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              _buildSectionHeader('Case Information'),
              TextFormField(
                controller: _caseNumberController,
                decoration: const InputDecoration(
                  labelText: 'Case Number',
                  prefixIcon: Icon(Icons.numbers),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _incidentTypeController.text.isEmpty
                    ? 'Traffic Collision'
                    : _incidentTypeController.text,
                items: const [
                  DropdownMenuItem(value: 'Traffic Collision', child: Text('Traffic Collision')),
                  DropdownMenuItem(value: 'Burglary', child: Text('Burglary')),
                  DropdownMenuItem(value: 'Assault', child: Text('Assault')),
                  DropdownMenuItem(value: 'Theft', child: Text('Theft')),
                  DropdownMenuItem(value: 'Vandalism', child: Text('Vandalism')),
                  DropdownMenuItem(value: 'Domestic Disturbance', child: Text('Domestic Disturbance')),
                  DropdownMenuItem(value: 'Suspicious Activity', child: Text('Suspicious Activity')),
                  DropdownMenuItem(value: 'Other', child: Text('Other (Specify)')),
                ],
                onChanged: (value) => _incidentTypeController.text = value!,
                decoration: const InputDecoration(
                  labelText: 'Incident Type*',
                  prefixIcon: Icon(Icons.warning_amber),
                ),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location*',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.gps_fixed),
                    onPressed: _getCurrentLocation,
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _incidentDate == null
                          ? 'No date selected'
                          : 'Date: ${DateFormat('MMM dd, yyyy').format(_incidentDate!)}',
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _incidentTime == null
                          ? 'No time selected'
                          : 'Time: ${_incidentTime!.format(context)}',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _pickDateTime,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Incident Details'),
              DropdownButtonFormField<String>(
                value: _severityLevel,
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'High', child: Text('High')),
                  DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                ],
                onChanged: (value) => setState(() => _severityLevel = value!),
                decoration: const InputDecoration(
                  labelText: 'Severity Level*',
                  prefixIcon: Icon(Icons.emergency),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description*',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Detailed description of the incident',
                ),
                maxLines: 5,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Suspect Information'),
              TextFormField(
                controller: _suspectNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter suspect full name',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _suspectDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Physical Description',
                  hintText: 'Height, build, hair color, distinguishing features',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _suspectContactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Information',
                  hintText: 'Phone, email, or other contact if known',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _suspectLastSeenController,
                decoration: const InputDecoration(
                  labelText: 'Last Known Location',
                  hintText: 'Where the suspect was last seen',
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Witness Information'),
              ..._witnessControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final witness = entry.value;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: witness['name'],
                            decoration: const InputDecoration(labelText: 'Witness Name'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeWitnessField(index),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: witness['contact'],
                      decoration: const InputDecoration(labelText: 'Contact Info'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: witness['statement'],
                      decoration: const InputDecoration(labelText: 'Statement'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addWitnessField,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add, size: 20),
                    SizedBox(width: 8),
                    Text('Add Another Witness'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Officer Information'),
              TextFormField(
                controller: _officerObservationsController,
                decoration: const InputDecoration(
                  labelText: 'Observations*',
                  prefixIcon: Icon(Icons.remove_red_eye),
                  hintText: 'Officer observations and evidence collected',
                ),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _actionsTakenController,
                decoration: const InputDecoration(
                  labelText: 'Actions Taken*',
                  prefixIcon: Icon(Icons.assignment_turned_in),
                  hintText: 'Response, arrests, citations, etc.',
                ),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Attachments'),
              Wrap(
                spacing: 8,
                children: [
                  ..._attachmentPaths.map((path) => Chip(
                    label: Text(path.split('/').last),
                    onDeleted: () => setState(() => _attachmentPaths.remove(path)),
                  )),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    onPressed: _addAttachment,
                    tooltip: 'Add photo evidence',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}