// lib/services/report_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils.dart';
import 'package:flutter/material.dart' show Color, IconData, Icons, Colors;

class ReportService {
  // Helper method to determine if token should be cleared
  static bool _shouldClearToken(Map<String, dynamic> responseData) {
    final error = responseData['error']?.toString().toLowerCase() ?? '';
    final message = responseData['message']?.toString().toLowerCase() ?? '';

    // Don't clear token for business logic errors
    if (error.contains('cannot vote on your own report') ||
        error.contains('already voted') ||
        message.contains('cannot vote on your own report')) {
      return false;
    }

    // Only clear token for actual authentication issues
    return error.contains('token') ||
        error.contains('expired') ||
        error.contains('invalid') ||
        error.contains('unauthorized') ||
        message.contains('log in again');
  }

  // Submit a new report
  static Future<Map<String, dynamic>> submitReport({
    required String category,
    required String description,
    required String urgencyLevel,
    required double latitude,
    required double longitude,
    File? image,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/reports/submit');

    try {
      final token = await _getToken();
      if (token == null) {
        return {
          "success": false,
          "error": "no_token",
          "message": "Please log in again",
        };
      }

      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['category'] = category;
      request.fields['description'] = description;
      request.fields['urgencyLevel'] = urgencyLevel;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (image != null) {
        final imageFile = await http.MultipartFile.fromPath(
          'image',
          image.path,
        );
        request.files.add(imageFile);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        return {
          "success": true,
          "message": data['message'] ?? "Report submitted successfully",
          "report": data['report'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (_shouldClearToken(data)) {
          print("Clearing token due to auth issue: ${data['error']}");
          await _clearToken();
        }
        return {
          "success": false,
          "error": "unauthorized",
          "message": data['error'] ?? 'Authentication failed',
        };
      } else {
        return {
          "success": false,
          "error": "submit_failed",
          "message": data['error'] ?? 'Failed to submit report',
        };
      }
    } catch (e) {
      print("Submit report error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred. Please try again.",
      };
    }
  }

  // Get reports near a location
  static Future<Map<String, dynamic>> getReportsNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 1.0,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/reports/nearby'
      '?lat=$latitude&lng=$longitude&radius=$radiusKm',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "reports": data['reports'] ?? []};
      } else {
        return {
          "success": false,
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch reports',
        };
      }
    } catch (e) {
      print("Get nearby reports error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Vote on a report
  static Future<Map<String, dynamic>> voteOnReport({
    required String reportId,
    required bool isUpvote,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/reports/$reportId/vote');

    try {
      final token = await _getToken();
      if (token == null) {
        return {
          "success": false,
          "error": "no_token",
          "message": "Please log in again",
        };
      }

      print("=== VOTE DEBUG ===");
      print(
        "Voting on report $reportId with ${isUpvote ? 'upvote' : 'downvote'}",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"vote": isUpvote ? "up" : "down"}),
      );

      print("Vote Response Status: ${response.statusCode}");
      print("Vote Response Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'] ?? "Vote recorded",
          "report": data['report'],
          "reputationUpdate": data['reputationUpdate'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Check if it's a business logic error vs auth error
        if (_shouldClearToken(data)) {
          print("Clearing token due to auth issue: ${data['error']}");
          await _clearToken();
          return {
            "success": false,
            "error": "unauthorized",
            "message": "Please log in again",
          };
        } else {
          // Business logic error - don't clear token
          print("Business logic error, keeping token: ${data['error']}");
          return {
            "success": false,
            "error": "vote_failed",
            "message": data['error'] ?? 'Cannot vote on this report',
          };
        }
      } else {
        return {
          "success": false,
          "error": "vote_failed",
          "message": data['error'] ?? 'Failed to record vote',
        };
      }
    } catch (e) {
      print("Vote on report error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Get user's report history
  static Future<Map<String, dynamic>> getUserReports() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/reports/my-reports');

    try {
      final token = await _getToken();
      if (token == null) {
        return {
          "success": false,
          "error": "no_token",
          "message": "Please log in again",
        };
      }

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "reports": data['reports'] ?? []};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (_shouldClearToken(data)) {
          await _clearToken();
        }
        return {
          "success": false,
          "error": "unauthorized",
          "message": data['error'] ?? 'Authentication failed',
        };
      } else {
        return {
          "success": false,
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch reports',
        };
      }
    } catch (e) {
      print("Get user reports error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Private token management methods
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    print("Token cleared from ReportService");
  }

  // Report categories helper
  static List<Map<String, dynamic>> getReportCategories() {
    return [
      {
        'id': 'poor_lighting',
        'title': 'Poor Lighting',
        'subtitle': 'Broken street lights, dark areas',
        'icon': 'lightbulb_outline',
        'color': 'amber',
      },
      {
        'id': 'suspicious_gathering',
        'title': 'Suspicious Gathering',
        'subtitle': 'Unusual groups or activities',
        'icon': 'group',
        'color': 'orange',
      },
      {
        'id': 'road_hazard',
        'title': 'Road Hazard',
        'subtitle': 'Obstacles, construction, damaged roads',
        'icon': 'warning',
        'color': 'red',
      },
      {
        'id': 'violence_assault',
        'title': 'Violence/Assault',
        'subtitle': 'Violent incidents or threats',
        'icon': 'dangerous',
        'color': 'red_700',
      },
      {
        'id': 'harassment',
        'title': 'Harassment',
        'subtitle': 'Unwanted attention or following',
        'icon': 'report_problem',
        'color': 'deep_orange',
      },
      {
        'id': 'police_security',
        'title': 'Police/Security Presence',
        'subtitle': 'Positive security presence',
        'icon': 'security',
        'color': 'blue',
      },
    ];
  }

  // Get urgency level color
  static String getUrgencyColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return 'green';
      case 'medium':
        return 'orange';
      case 'high':
        return 'red';
      default:
        return 'grey';
    }
  }

  // Format report date
  static String formatReportDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get reputation color for score
  static Color getReputationColor(int score) {
    if (score >= 76) return Colors.purple;
    if (score >= 51) return Colors.green;
    if (score >= 26) return Colors.blue;
    return Colors.grey;
  }

  // Get badge icon for level
  static IconData getBadgeIcon(String badgeLevel) {
    switch (badgeLevel) {
      case 'newcomer':
        return Icons.star_border;
      case 'regular':
        return Icons.star_half;
      case 'trusted':
        return Icons.star;
      case 'expert':
        return Icons.stars;
      default:
        return Icons.star_border;
    }
  }
}
