import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:city_path/screens/report_hazard_screen.dart';
import 'dart:async';
import 'dart:math' as math;

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic> selectedRoute;
  final String destinationAddress;

  const NavigationScreen({
    super.key,
    required this.selectedRoute,
    required this.destinationAddress,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Current user location
  LatLng? _currentLocation;

  // Route data
  List<LatLng> _routePoints = [];
  int _currentStepIndex = 0;

  // Navigation state
  String _currentInstruction = "Starting navigation...";
  String _nextInstruction = "";
  double _distanceToNextStep = 0.0;
  double _totalDistanceRemaining = 0.0;
  int _estimatedTimeRemaining = 0; // in minutes

  // Map settings
  double _currentZoom = 18.0;
  double _currentBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeRoute();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Initialize route from selected route data
  void _initializeRoute() {
    final List<dynamic> pathData = widget.selectedRoute['path'] ?? [];
    _routePoints =
        pathData.map<LatLng>((coord) => LatLng(coord[0], coord[1])).toList();

    if (_routePoints.isNotEmpty) {
      _currentInstruction = "Head towards ${widget.destinationAddress}";
      _calculateRemainingDistance();
    }
  }

  // Start real-time location tracking
  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateCurrentLocation(position);
    });
  }

  // Update current location and navigation state
  void _updateCurrentLocation(Position position) {
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentBearing = position.heading;
    });

    _updateNavigationInstructions();
    _updateMapCamera();
  }

  // Calculate remaining distance and time
  void _calculateRemainingDistance() {
    if (_currentLocation == null || _routePoints.isEmpty) return;

    double totalDistance = 0.0;

    // Calculate distance from current location to next step
    if (_currentStepIndex < _routePoints.length) {
      totalDistance += Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _routePoints[_currentStepIndex].latitude,
        _routePoints[_currentStepIndex].longitude,
      );
    }

    // Add remaining steps
    for (int i = _currentStepIndex; i < _routePoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }

    setState(() {
      _totalDistanceRemaining = totalDistance;
      // Estimate time: average walking speed 5 km/h = 1.39 m/s
      _estimatedTimeRemaining = (totalDistance / 1.39 / 60).round();
    });
  }

  // Update navigation instructions based on current location
  void _updateNavigationInstructions() {
    if (_currentLocation == null || _routePoints.isEmpty) return;

    // Check if we're close to the next waypoint
    if (_currentStepIndex < _routePoints.length) {
      double distanceToNext = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _routePoints[_currentStepIndex].latitude,
        _routePoints[_currentStepIndex].longitude,
      );

      setState(() {
        _distanceToNextStep = distanceToNext;
      });

      // If close to waypoint, move to next step
      if (distanceToNext < 20.0 &&
          _currentStepIndex < _routePoints.length - 1) {
        _currentStepIndex++;
        _generateInstructions();
      }
    }

    _calculateRemainingDistance();
  }

  // Generate turn-by-turn instructions
  void _generateInstructions() {
    if (_currentStepIndex >= _routePoints.length - 1) {
      setState(() {
        _currentInstruction = "You have arrived at your destination!";
        _nextInstruction = "";
      });
      return;
    }

    // Simple instruction generation (can be enhanced)
    if (_currentStepIndex == 0) {
      setState(() {
        _currentInstruction = "Head towards ${widget.destinationAddress}";
        _nextInstruction = "Continue straight";
      });
    } else if (_currentStepIndex < _routePoints.length - 2) {
      String direction = _calculateTurnDirection(_currentStepIndex);
      setState(() {
        _currentInstruction = direction;
        _nextInstruction = "Then continue straight";
      });
    } else {
      setState(() {
        _currentInstruction = "Continue to destination";
        _nextInstruction = "You're almost there!";
      });
    }
  }

  // Calculate turn direction based on route points
  String _calculateTurnDirection(int stepIndex) {
    if (stepIndex < 1 || stepIndex >= _routePoints.length - 1) {
      return "Continue straight";
    }

    LatLng prev = _routePoints[stepIndex - 1];
    LatLng current = _routePoints[stepIndex];
    LatLng next = _routePoints[stepIndex + 1];

    // Calculate bearings
    double bearing1 = Geolocator.bearingBetween(
      prev.latitude,
      prev.longitude,
      current.latitude,
      current.longitude,
    );
    double bearing2 = Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      next.latitude,
      next.longitude,
    );

    double turnAngle = bearing2 - bearing1;
    if (turnAngle > 180) turnAngle -= 360;
    if (turnAngle < -180) turnAngle += 360;

    if (turnAngle.abs() < 30) return "Continue straight";
    if (turnAngle > 30) return "Turn right";
    if (turnAngle < -30) return "Turn left";
    return "Continue straight";
  }

  // Update map camera to follow user
  void _updateMapCamera() {
    if (_mapController == null || _currentLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation!,
          zoom: _currentZoom,
          bearing: _currentBearing,
          tilt: 60.0, // 3D perspective
        ),
      ),
    );
  }

  // Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }

  // Format time for display
  String _formatTime(int minutes) {
    if (minutes < 60) {
      return "$minutes min";
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return "${hours}h ${remainingMinutes}m";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLocation != null) {
                _updateMapCamera();
              }
            },
            initialCameraPosition: CameraPosition(
              target:
                  _routePoints.isNotEmpty
                      ? _routePoints.first
                      : const LatLng(32.0853, 34.7818),
              zoom: _currentZoom,
              bearing: _currentBearing,
              tilt: 60.0,
            ),
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                color: Colors.blue,
                width: 6,
              ),
            },
            markers:
                _routePoints.isNotEmpty
                    ? {
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: _routePoints.last,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                    }
                    : {},
          ),

          // Top instruction panel
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getInstructionIcon(_currentInstruction),
                          size: 32,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentInstruction,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_distanceToNextStep > 0)
                                Text(
                                  "in ${_formatDistance(_distanceToNextStep)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_nextInstruction.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "Then: $_nextInstruction",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom info panel
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.blue),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(_estimatedTimeRemaining),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Remaining",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten, color: Colors.green),
                        const SizedBox(height: 4),
                        Text(
                          _formatDistance(_totalDistanceRemaining),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Distance",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag, color: Colors.red),
                        const SizedBox(height: 4),
                        Text(
                          "${_routePoints.length - _currentStepIndex}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Steps left",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Exit button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Card(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportHazardScreen()),
          );

          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Report submitted! Thank you for helping keep routes safe.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
        child: const Icon(Icons.report_problem, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Get appropriate icon for instruction
  IconData _getInstructionIcon(String instruction) {
    if (instruction.contains("right")) return Icons.turn_right;
    if (instruction.contains("left")) return Icons.turn_left;
    if (instruction.contains("straight")) return Icons.straight;
    if (instruction.contains("arrived")) return Icons.location_on;
    return Icons.navigation;
  }
}
