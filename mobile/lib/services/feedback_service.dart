// lib/services/feedback_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils.dart';

class FeedbackService {
  // Submit route feedback
  static Future<Map<String, dynamic>> submitRouteFeedback({
    required Map<String, dynamic> routeData,
    required int safetyRating,
    required int accuracyRating,
    required bool wouldUseAgain,
    String? comments,
    Duration? actualDuration,
    List<Map<String, dynamic>>? encounteredReports,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/feedback/submit');

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
        body: jsonEncode({
          "routeData": routeData,
          "safetyRating": safetyRating,
          "accuracyRating": accuracyRating,
          "wouldUseAgain": wouldUseAgain,
          "comments": comments,
          "actualDuration": actualDuration?.inMinutes,
          "encounteredReports": encounteredReports ?? [],
        }),
      );

      print("Feedback Response Status: ${response.statusCode}");
      print("Feedback Response Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          "success": true,
          "message": data['message'] ?? "Feedback submitted successfully",
          "feedbackId": data['feedbackId'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Check if token should be cleared
        if (_shouldClearToken(data)) {
          await _clearToken();
          return {
            "success": false,
            "error": "unauthorized",
            "message": "Please log in again",
          };
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
          "message": data['error'] ?? 'Failed to submit feedback',
        };
      }
    } catch (e) {
      print("Submit feedback error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred. Please try again.",
      };
    }
  }

  // Get feedback analytics (optional - for admin dashboard)
  static Future<Map<String, dynamic>> getFeedbackAnalytics() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/feedback/analytics');

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
        return {"success": true, "analytics": data['analytics']};
      } else {
        return {
          "success": false,
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch analytics',
        };
      }
    } catch (e) {
      print("Get analytics error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Helper method to determine if token should be cleared
  static bool _shouldClearToken(Map<String, dynamic> responseData) {
    final error = responseData['error']?.toString().toLowerCase() ?? '';
    final message = responseData['message']?.toString().toLowerCase() ?? '';

    // Only clear token for actual authentication issues
    return error.contains('token') ||
        error.contains('expired') ||
        error.contains('invalid') ||
        error.contains('unauthorized') ||
        message.contains('log in again');
  }

  // Private token management methods
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    print("Token cleared from FeedbackService");
  }
}
