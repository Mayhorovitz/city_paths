import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  // Register new user
  static Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "email": email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          "success": true,
          "message": data['message'],
          "user": data['user'],
        };
      } else if (response.statusCode == 409) {
        // User already exists
        return {
          "success": false,
          "error": "user_exists",
          "message": data['message'],
        };
      } else {
        return {
          "success": false,
          "error": "registration_failed",
          "message": data['error'],
        };
      }
    } catch (e) {
      print("Registration error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Login existing user
  static Future<Map<String, dynamic>> loginUser({
    required String phoneOrEmail,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    try {
      // Determine if input is phone or email
      final isEmail = phoneOrEmail.contains('@');
      final body =
          isEmail
              ? {"email": phoneOrEmail, "phone": phoneOrEmail}
              : {"phone": phoneOrEmail, "email": phoneOrEmail};

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'],
          "user": data['user'],
        };
      } else if (response.statusCode == 404) {
        // User not found
        return {
          "success": false,
          "error": "user_not_found",
          "message": data['message'],
        };
      } else {
        return {
          "success": false,
          "error": "login_failed",
          "message": data['error'],
        };
      }
    } catch (e) {
      print("Login error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Verify code
  static Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/verify');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "code": code}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'],
          "user": data['user'],
        };
      } else {
        return {
          "success": false,
          "error": "verification_failed",
          "message": data['error'],
        };
      }
    } catch (e) {
      print("Verification error: $e");
      return {
        "success": false,
        "error": "network_error",
        "message": "Network error occurred",
      };
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getUserProfile(String phone) async {
    final url = Uri.parse('$baseUrl/api/auth/profile/$phone');

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "user": data['user']};
      } else {
        return {"success": false, "error": data['error']};
      }
    } catch (e) {
      print("Profile fetch error: $e");
      return {"success": false, "error": "network_error"};
    }
  }

  // Legacy method for backward compatibility
  static Future<bool> sendRegisterRequest(String emailOrPhone) async {
    final result = await loginUser(phoneOrEmail: emailOrPhone);
    return result['success'] ?? false;
  }
}
