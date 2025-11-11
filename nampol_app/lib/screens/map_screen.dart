import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<QuerySnapshot>? _otherOfficersSubscription;
  List<LatLng> _pathHistory = [];
  bool _isPatrolling = false;
  DateTime? _patrolStartTime;
  double _distanceCovered = 0.0;
  Position? _lastPosition;
  late User? _currentUser;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _initializeLocationTracking();
    _startWatchingOtherOfficers();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _otherOfficersSubscription?.cancel();
    // Auto-stop patrol if active
    if (_isPatrolling) {
      _stopPatrol();
    }
    super.dispose();
  }

  Future<void> _initializeLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDisabledDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationPermissionDeniedDialog();
      return;
    }

    // Get initial position
    await _getCurrentLocation();

    // Start continuous location updates
    _startContinuousLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _startContinuousLocationUpdates() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (_isPatrolling) {
            _updatePatrolData(position);
          }
        });
        _updateMap(position);
      }
    });
  }

  void _updatePatrolData(Position newPosition) {
    // Calculate distance from last position
    if (_lastPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      _distanceCovered += distanceInMeters;
    }
    _lastPosition = newPosition;

    // Add to path history
    _pathHistory.add(LatLng(newPosition.latitude, newPosition.longitude));

    // Update polyline
    if (_pathHistory.length > 1) {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('patrol_path'),
        points: _pathHistory,
        color: Colors.blue,
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    // Update officer location in Firestore
    _updateOfficerLocation(newPosition);
  }

  void _updateOfficerLocation(Position position) {
    if (_currentUser == null || !_isPatrolling) return;

    // Update the officer's document with current location
    _firestore.collection('patrol_sessions').doc(_currentUser!.uid).update({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': position.speed,
      'heading': position.heading,
      'accuracy': position.accuracy,
      'lastUpdate': FieldValue.serverTimestamp(),
      'distanceCovered': _distanceCovered,
    });
  }

  void _togglePatrol() {
    setState(() {
      _isPatrolling = !_isPatrolling;
      if (_isPatrolling) {
        _startPatrol();
      } else {
        _stopPatrol();
      }
    });
  }

  void _startPatrol() {
    if (_currentUser == null || _currentPosition == null) return;

    // Create/update patrol session document
    _firestore.collection('patrol_sessions').doc(_currentUser!.uid).set({
      'officerId': _currentUser!.uid,
      'officerName': _currentUser!.displayName ?? 'Unknown Officer',
      'officerEmail': _currentUser!.email,
      'isActive': true,
      'startTime': FieldValue.serverTimestamp(),
      'lastUpdate': FieldValue.serverTimestamp(),
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'speed': _currentPosition!.speed,
      'heading': _currentPosition!.heading,
      'accuracy': _currentPosition!.accuracy,
      'distanceCovered': 0.0,
    });

    _patrolStartTime = DateTime.now();
    _pathHistory.clear();
    _distanceCovered = 0.0;
    if (_currentPosition != null) {
      _pathHistory.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      _lastPosition = _currentPosition;
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patrol started - Live tracking active'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopPatrol() {
    if (_currentUser == null) return;

    // Mark patrol as inactive
    _firestore.collection('patrol_sessions').doc(_currentUser!.uid).update({
      'isActive': false,
      'endTime': FieldValue.serverTimestamp(),
      'totalDistance': _distanceCovered,
      'durationMinutes': _patrolStartTime != null
          ? DateTime.now().difference(_patrolStartTime!).inMinutes
          : 0,
    });

    _showPatrolSummary();
  }

  void _updateMap(Position position) {
    if (_currentUser == null) return;

    final marker = Marker(
      markerId: MarkerId(_currentUser!.uid),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: InfoWindow(
        title: 'You - ${_currentUser!.displayName ?? "Officer"}',
        snippet: 'Speed: ${position.speed?.toStringAsFixed(1) ?? 'N/A'} m/s',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _isPatrolling ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue,
      ),
    );

    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == _currentUser!.uid);
      _markers.add(marker);
    });

    if (_isPatrolling) {
      _mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    }
  }

  // Stream to watch other officers on patrol
  Stream<QuerySnapshot> get _otherOfficersStream {
    if (_currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('patrol_sessions')
        .where('isActive', isEqualTo: true)
        .where('officerId', isNotEqualTo: _currentUser!.uid)
        .snapshots();
  }

  void _startWatchingOtherOfficers() {
    _otherOfficersSubscription = _otherOfficersStream.listen((QuerySnapshot snapshot) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateOtherOfficersMarkers(snapshot.docs);
      });
    });
  }

  void _updateOtherOfficersMarkers(List<QueryDocumentSnapshot> docs) {
    if (!mounted) return;

    setState(() {
      // Remove all other officers' markers except current user
      _markers.removeWhere((marker) => marker.markerId.value != _currentUser!.uid);

      // Add markers for other active officers
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['latitude'] != null && data['longitude'] != null) {
          final marker = Marker(
            markerId: MarkerId(data['officerId']),
            position: LatLng(data['latitude'], data['longitude']),
            infoWindow: InfoWindow(
              title: data['officerName'] ?? 'Officer',
              snippet: 'On Patrol - ${_getLastUpdateTime(data['lastUpdate'])}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          );
          _markers.add(marker);
        }
      }
    });
  }

  String _getLastUpdateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final duration = DateTime.now().difference(timestamp.toDate());
    if (duration.inSeconds < 60) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    return '${duration.inHours}h ago';
  }

  void _showLocationServiceDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services to use patrol tracking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Denied'),
        content: const Text('This app needs location permission to track patrol routes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPatrolSummary() {
    final duration = _patrolStartTime != null
        ? DateTime.now().difference(_patrolStartTime!)
        : Duration.zero;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Patrol Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(Icons.timer, 'Duration',
                '${duration.inMinutes} minutes ${duration.inSeconds.remainder(60)} seconds'),
            _buildSummaryRow(Icons.directions_walk, 'Distance Covered',
                '${(_distanceCovered).toStringAsFixed(2)} meters'),
            _buildSummaryRow(Icons.place, 'Path Points',
                '${_pathHistory.length} recorded'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  void _showActiveOfficers() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: _otherOfficersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeOfficers = snapshot.data!.docs;

          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Active Patrols',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (activeOfficers.isEmpty)
                  const Text('No other officers on patrol')
                else
                  ...activeOfficers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.person_pin_circle, color: Colors.green),
                      title: Text(data['officerName'] ?? 'Officer'),
                      subtitle: Text(
                        'Last update: ${_getLastUpdateTime(data['lastUpdate'])}',
                      ),
                      trailing: Text(
                        '${data['speed']?.toStringAsFixed(1) ?? 'N/A'} m/s',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        if (data['latitude'] != null && data['longitude'] != null) {
                          _mapController.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(data['latitude'], data['longitude']),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                    );
                  }),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Patrol Tracking'),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _showActiveOfficers,
            tooltip: 'Active Officers',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  ),
                );
              }
            },
            tooltip: 'Center on Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Getting your location...'),
              ],
            ),
          )
              : GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 16.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _togglePatrol,
              backgroundColor: _isPatrolling ? Colors.red : Colors.blue,
              child: Icon(
                _isPatrolling ? Icons.stop : Icons.directions_walk,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          if (_isPatrolling)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '🚔 PATROLLING - LIVE TRACKING ACTIVE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Officer: ${_currentUser?.displayName ?? 'Unknown'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isPatrolling && _currentPosition != null)
            Positioned(
              bottom: 80,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('📍 Speed', '${_currentPosition!.speed?.toStringAsFixed(1) ?? 'N/A'} m/s'),
                    _buildInfoRow('🎯 Accuracy', '${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
                    _buildInfoRow('📏 Distance', '${_distanceCovered.toStringAsFixed(2)}m'),
                    _buildInfoRow('📊 Points', '${_pathHistory.length}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontFamily: 'Monospace'),
          ),
        ],
      ),
    );
  }
}