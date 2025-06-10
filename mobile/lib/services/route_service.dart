import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  static Future<Map<String, dynamic>> fetchSafeRoutes({
    required List<double> origin,
    required List<double> destination,
  }) async {
    final url = Uri.parse('$baseUrl/api/routes/calculate');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"origin": origin, "destination": destination}),
      );

      print('Route API Response Status: ${response.statusCode}');
      print('Route API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          return data; // מחזיר את כל התגובה כולל routes, recommendation וכו'
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
