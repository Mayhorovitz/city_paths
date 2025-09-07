import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart';

class RouteService {
  static Future<Map<String, dynamic>> fetchSafeRoutes({
    required List<double> origin,
    required List<double> destination,
    int? userId, // Optional user ID for preferences
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/routes/calculate');

    try {
      final Map<String, dynamic> body = {
        "origin": origin,
        "destination": destination,
      };

      // Add userId if provided
      if (userId != null) {
        body["userId"] = userId;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('Route API Response Status: ${response.statusCode}');
      print('Route API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          // Log preferences information
          final scoringInfo = data['scoringInfo'];
          if (scoringInfo != null) {
            print('Scoring Info: ${scoringInfo['message']}');
            print('Preferences Used: ${scoringInfo['preferencesUsed']}');
            print('Preferences Source: ${scoringInfo['preferencesSource']}');
          }

          return data;
        } else {
          throw Exception("Server returned success: false");
        }
      } else {
        print("Error fetching routes: ${response.body}");
        throw Exception("Failed to fetch routes: ${response.statusCode}");
      }
    } catch (e) {
      print("RouteService error: $e");
      throw Exception("Network error: $e");
    }
  }
}
