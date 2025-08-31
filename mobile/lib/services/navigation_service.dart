// lib/services/navigation_service.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class NavigationService {
  late List<LatLng> _routePoints;
  int _currentStepIndex = 0;
  String _currentInstruction = "Starting navigation...";
  String _nextInstruction = "";
  double _distanceToNextStep = 0.0;
  double _totalDistanceRemaining = 0.0;
  int _estimatedTimeRemaining = 0;

  // Getters
  List<LatLng> get routePoints => _routePoints;
  int get currentStepIndex => _currentStepIndex;
  String get currentInstruction => _currentInstruction;
  String get nextInstruction => _nextInstruction;
  double get distanceToNextStep => _distanceToNextStep;
  double get totalDistanceRemaining => _totalDistanceRemaining;
  int get estimatedTimeRemaining => _estimatedTimeRemaining;

  void initializeRoute(
    Map<String, dynamic> selectedRoute,
    String destinationAddress,
  ) {
    final List<dynamic> pathData = selectedRoute['path'] ?? [];
    _routePoints =
        pathData.map<LatLng>((coord) => LatLng(coord[0], coord[1])).toList();

    if (_routePoints.isNotEmpty) {
      _currentInstruction = "Head towards $destinationAddress";
    }
  }

  void updateLocation(LatLng currentLocation) {
    _calculateRemainingDistance(currentLocation);
    _updateNavigationInstructions(currentLocation);
  }

  void _calculateRemainingDistance(LatLng currentLocation) {
    if (_routePoints.isEmpty) return;

    double totalDistance = 0.0;

    // Distance from current location to next step
    if (_currentStepIndex < _routePoints.length) {
      totalDistance += Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
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

    _totalDistanceRemaining = totalDistance;
    _estimatedTimeRemaining =
        (totalDistance / 1.39 / 60).round(); // 5 km/h walking speed
  }

  void _updateNavigationInstructions(LatLng currentLocation) {
    if (_routePoints.isEmpty) return;

    // Check if close to next waypoint
    if (_currentStepIndex < _routePoints.length) {
      double distanceToNext = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        _routePoints[_currentStepIndex].latitude,
        _routePoints[_currentStepIndex].longitude,
      );

      _distanceToNextStep = distanceToNext;

      // Move to next step if close enough
      if (distanceToNext < 20.0 &&
          _currentStepIndex < _routePoints.length - 1) {
        _currentStepIndex++;
        _generateInstructions();
      }
    }
  }

  void _generateInstructions() {
    if (_currentStepIndex >= _routePoints.length - 1) {
      _currentInstruction = "You have arrived at your destination!";
      _nextInstruction = "";
      return;
    }

    if (_currentStepIndex == 0) {
      _currentInstruction = "Head towards destination";
      _nextInstruction = "Continue straight";
    } else if (_currentStepIndex < _routePoints.length - 2) {
      String direction = _calculateTurnDirection(_currentStepIndex);
      _currentInstruction = direction;
      _nextInstruction = "Then continue straight";
    } else {
      _currentInstruction = "Continue to destination";
      _nextInstruction = "You're almost there!";
    }
  }

  String _calculateTurnDirection(int stepIndex) {
    if (stepIndex < 1 || stepIndex >= _routePoints.length - 1) {
      return "Continue straight";
    }

    LatLng prev = _routePoints[stepIndex - 1];
    LatLng current = _routePoints[stepIndex];
    LatLng next = _routePoints[stepIndex + 1];

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
}
