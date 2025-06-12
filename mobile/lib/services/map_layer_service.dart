import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart';

class MapLayerService {
  // Fetch GeoJSON for a specific layer (e.g. "crime", "lighting", "business")
  static Future<Map<String, dynamic>> fetchLayer(String type) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/layers?type=$type');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load layer: $type');
    }
  }
}
