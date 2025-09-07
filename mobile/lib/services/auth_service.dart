// lib/services/auth_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils.dart';
import 'package:flutter/material.dart' show Color, IconData, Icons, Colors;

class AuthService {
  // Helper method to determine if token should be cleared
  static bool _shouldClearToken(Map<String, dynamic> responseData) {
    final error = responseData['error']?.toString().toLowerCase() ?? '';

    // Only clear token for actual authentication issues
    return error.contains('token') ||
        error.contains('expired') ||
        error.contains('invalid') ||
        error.contains('unauthorized') ||
        responseData['message']?.toString().toLowerCase().contains(
              'log in again',
            ) ==
            true;
  }

  // Register new user with preferences
  static Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    double lightingPreference = 0.30,
    double businessPreference = 0.25,
    double crimePreference = 0.20,
    double reportsPreference = 0.25,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "email": email,
          "password": password,
          "firstName": firstName,
          "lastName": lastName,
          "dateOfBirth": dateOfBirth,
          "lightingPreference": lightingPreference,
          "businessPreference": businessPreference,
          "crimePreference": crimePreference,
          "reportsPreference": reportsPreference,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }

        return {
          "success": true,
          "message": data['message'],
          "user": data['user'],
          "token": data['token'],
        };
      } else if (response.statusCode == 409) {
        return {
          "success": false,
          "error": "user_exists",
          "message": data['message'] ?? data['error'],
        };
      } else {
        return {
          "success": false,
          "error": "registration_failed",
          "message": data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print("Registration error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred. Please check your connection.",
      };
    }
  }

  // Login user
  static Future<Map<String, dynamic>> loginUser({
    required String phoneOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phoneOrEmail": phoneOrEmail, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }

        return {
          "success": true,
          "message": data['message'],
          "user": data['user'],
          "token": data['token'],
        };
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "error": "invalid_credentials",
          "message": data['message'] ?? 'Invalid credentials',
          "attemptsRemaining": data['attemptsRemaining'],
        };
      } else if (response.statusCode == 423) {
        return {
          "success": false,
          "error": "account_locked",
          "message": data['message'] ?? 'Account is temporarily locked',
        };
      } else {
        return {
          "success": false,
          "error": "login_failed",
          "message": data['error'] ?? data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print("Login error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred. Please check your connection.",
      };
    }
  }

  // Get user profile with reputation info and preferences
  static Future<Map<String, dynamic>> getUserProfile() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/users/profile');

    try {
      final token = await _getToken();
      print("=== AUTH DEBUG: getUserProfile ===");
      print("Token exists: ${token != null}");

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

      print("Profile Response Status: ${response.statusCode}");
      print("Profile Response Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "user": data['user']};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Only clear token if it's actually an auth issue
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
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch profile',
        };
      }
    } catch (e) {
      print("Profile fetch error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Update user preferences
  static Future<Map<String, dynamic>> updatePreferences({
    required double lightingPreference,
    required double businessPreference,
    required double crimePreference,
    required double reportsPreference,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/preferences');

    try {
      final token = await _getToken();
      if (token == null) {
        return {
          "success": false,
          "error": "no_token",
          "message": "Please log in again",
        };
      }

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "lightingPreference": lightingPreference,
          "businessPreference": businessPreference,
          "crimePreference": crimePreference,
          "reportsPreference": reportsPreference,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'],
          "preferences": data['preferences'],
        };
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
          "error": "update_failed",
          "message": data['error'] ?? 'Failed to update preferences',
        };
      }
    } catch (e) {
      print("Preferences update error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Get preference presets
  static Future<Map<String, dynamic>> getPreferencePresets() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/presets');

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "presets": data['presets']};
      } else {
        return {
          "success": false,
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch presets',
        };
      }
    } catch (e) {
      print("Presets fetch error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred: $e",
      };
    }
  }

  // Get reputation details
  static Future<Map<String, dynamic>> getReputationDetails() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/users/reputation');

    try {
      final token = await _getToken();
      print("=== AUTH DEBUG: getReputationDetails ===");
      print("Token exists: ${token != null}");

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

      print("Reputation Response Status: ${response.statusCode}");
      print("Reputation Response Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "reputationDetails": data['reputationDetails'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Only clear token if it's actually an auth issue
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
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch reputation details',
        };
      }
    } catch (e) {
      print("Reputation fetch error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred: $e",
      };
    }
  }

  // Get leaderboard
  static Future<Map<String, dynamic>> getLeaderboard({int limit = 20}) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/leaderboard?limit=$limit',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "leaderboard": data['leaderboard'],
          "count": data['count'],
        };
      } else {
        return {
          "success": false,
          "error": "fetch_failed",
          "message": data['error'] ?? 'Failed to fetch leaderboard',
        };
      }
    } catch (e) {
      print("Leaderboard fetch error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred: $e",
      };
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? profilePicture,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/profile');

    try {
      final token = await _getToken();
      if (token == null) {
        return {
          "success": false,
          "error": "no_token",
          "message": "Please log in again",
        };
      }

      final body = <String, dynamic>{};
      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;
      if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;
      if (profilePicture != null) body['profilePicture'] = profilePicture;

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'],
          "user": data['user'],
        };
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
          "error": "update_failed",
          "message": data['error'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      print("Profile update error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/change-password');

    try {
      final token = await _getToken();
      if (token == null) {
        return {
          "success": false,
          "error": "no_token",
          "message": "Please log in again",
        };
      }

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message']};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "error": "wrong_password",
          "message": data['error'] ?? 'Current password is incorrect',
        };
      } else if (response.statusCode == 403) {
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
          "error": "change_failed",
          "message": data['error'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      print("Password change error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Logout user
  static Future<void> logout() async {
    await _clearToken();
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null;
  }

  // Private methods for token management
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("Token saved successfully");
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    print("Token cleared");
  }

  // Validation helpers
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(
      r'^(\+972|0)?[5-9]\d{8}$',
    ).hasMatch(phone.replaceAll(RegExp(r'[-\s]'), ''));
  }

  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Helper methods for preference validation
  static bool isValidPreferences(
    double lighting,
    double business,
    double crime,
    double reports,
  ) {
    final total = lighting + business + crime + reports;
    return (total - 1.0).abs() < 0.01 &&
        [
          lighting,
          business,
          crime,
          reports,
        ].every((pref) => pref >= 0 && pref <= 1);
  }

  static Map<String, double> normalizePreferences(
    double lighting,
    double business,
    double crime,
    double reports,
  ) {
    final total = lighting + business + crime + reports;
    if (total <= 0) {
      return {
        'lighting': 0.30,
        'business': 0.25,
        'crime': 0.20,
        'reports': 0.25,
      };
    }
    return {
      'lighting': lighting / total,
      'business': business / total,
      'crime': crime / total,
      'reports': reports / total,
    };
  }

  // Helper methods for badge display
  static String getBadgeDisplayName(String badgeLevel) {
    switch (badgeLevel) {
      case 'newcomer':
        return 'New Reporter';
      case 'regular':
        return 'Regular Reporter';
      case 'trusted':
        return 'Trusted Reporter';
      case 'expert':
        return 'Expert Reporter';
      default:
        return 'Reporter';
    }
  }

  static Color getBadgeColor(String badgeLevel) {
    switch (badgeLevel) {
      case 'newcomer':
        return Colors.grey;
      case 'regular':
        return Colors.blue;
      case 'trusted':
        return Colors.green;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

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

  // Helper methods for preference presets
  static Map<String, Map<String, double>> getDefaultPresets() {
    return {
      'balanced': {
        'lighting': 0.30,
        'business': 0.25,
        'crime': 0.20,
        'reports': 0.25,
      },
      'lighting_focused': {
        'lighting': 0.70,
        'business': 0.15,
        'crime': 0.10,
        'reports': 0.05,
      },
      'business_focused': {
        'lighting': 0.20,
        'business': 0.60,
        'crime': 0.10,
        'reports': 0.10,
      },
      'crime_focused': {
        'lighting': 0.25,
        'business': 0.15,
        'crime': 0.50,
        'reports': 0.10,
      },
      'community_focused': {
        'lighting': 0.20,
        'business': 0.20,
        'crime': 0.10,
        'reports': 0.50,
      },
    };
  }

  static String getPresetDisplayName(String presetName) {
    switch (presetName) {
      case 'balanced':
        return 'Balanced';
      case 'lighting_focused':
        return 'Lighting Focused';
      case 'business_focused':
        return 'Business Areas';
      case 'crime_focused':
        return 'Crime Avoidance';
      case 'community_focused':
        return 'Community Reports';
      default:
        return presetName;
    }
  }

  static String getPresetDescription(String presetName) {
    switch (presetName) {
      case 'balanced':
        return 'Balanced safety priorities for all situations';
      case 'lighting_focused':
        return 'Prioritize well-lit areas above all else';
      case 'business_focused':
        return 'Prefer areas with open businesses and activity';
      case 'crime_focused':
        return 'Maximum avoidance of high crime areas';
      case 'community_focused':
        return 'Trust community reports and crowdsourced data';
      default:
        return 'Custom preference preset';
    }
  }
}
