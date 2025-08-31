// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  static const List<double> defaultLocation = [32.0853, 34.7818]; // Tel Aviv

  static Future<List<double>?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return defaultLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return defaultLocation;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return [position.latitude, position.longitude];
    } catch (e) {
      print("Error getting current location: $e");
      return defaultLocation;
    }
  }

  static StreamSubscription<Position>? startLocationStream({
    required Function(Position) onLocationUpdate,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(onLocationUpdate);
  }

  static double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }

  static String formatTime(int minutes) {
    if (minutes < 60) {
      return "$minutes min";
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return "${hours}h ${remainingMinutes}m";
    }
  }
}
