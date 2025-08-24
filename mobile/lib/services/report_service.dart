import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils.dart';

class ReportService {
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

      // Create multipart request for file upload
      final request = http.MultipartRequest('POST', url);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['category'] = category;
      request.fields['description'] = description;
      request.fields['urgencyLevel'] = urgencyLevel;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      // Add image if provided
      if (image != null) {
        final imageFile = await http.MultipartFile.fromPath(
          'image',
          image.path,
        );
        request.files.add(imageFile);
      }

      // Send request
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
        await _clearToken();
        return {
          "success": false,
          "error": "unauthorized",
          "message": "Please log in again",
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
        await _clearToken();
        return {
          "success": false,
          "error": "unauthorized",
          "message": "Please log in again",
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

  // Vote on a report (upvote/downvote for verification)
  static Future<Map<String, dynamic>> voteOnReport({
    required String reportId,
    required bool isUpvote, // true for upvote, false for downvote
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

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"vote": isUpvote ? "up" : "down"}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'] ?? "Vote recorded",
          "report": data['report'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearToken();
        return {
          "success": false,
          "error": "unauthorized",
          "message": "Please log in again",
        };
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

  // Private token management methods
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}
