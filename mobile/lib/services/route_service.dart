import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  static Future<List<Map<String, dynamic>>> fetchSafeRoutes({
    required List<double> origin,
    required List<double> destination,
  }) async {
    final url = Uri.parse('$baseUrl/api/routes/calculate');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"origin": origin, "destination": destination}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      print("Error fetching routes: ${response.body}");
      throw Exception("Failed to fetch routes");
    }
  }
}
