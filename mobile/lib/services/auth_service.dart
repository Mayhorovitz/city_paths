import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils.dart';

class AuthService {
  // Register new user
  static Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
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
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Save token to local storage
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
        // Save token to local storage
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

  // Get user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
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

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "user": data['user']};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearToken(); // Clear invalid token
        return {
          "success": false,
          "error": "unauthorized",
          "message": "Please log in again",
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
        await _clearToken();
        return {
          "success": false,
          "error": "unauthorized",
          "message": "Please log in again",
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
        await _clearToken();
        return {
          "success": false,
          "error": "unauthorized",
          "message": "Please log in again",
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
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Validation helpers
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    // Israeli phone validation
    return RegExp(
      r'^(\+972|0)?[5-9]\d{8}$',
    ).hasMatch(phone.replaceAll(RegExp(r'[-\s]'), ''));
  }

  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}
