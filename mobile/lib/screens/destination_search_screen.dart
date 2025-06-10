import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;

  // Google Places API autocomplete
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=${dotenv.env['MAPS_API_KEY']}'
        '&components=country:il'
        '&language=en',
      );

      print('Making request to Places API...');

      final response = await http.get(url);

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('API Response status: ${data['status']}');

        if (data['status'] == 'OK') {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(
              data['predictions'] ?? [],
            );
          });
          print('Found ${_predictions.length} predictions');
        } else {
          print(
            'API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Search error: ${data['status']}')),
            );
          }
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching places: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching places: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get place details by place_id
  Future<void> _getPlaceDetails(String placeId, String description) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=${dotenv.env['MAPS_API_KEY']}'
        '&fields=geometry,formatted_address',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];

          Navigator.pop(context, {
            "address": result['formatted_address'] ?? description,
            "latlng": [location['lat'], location['lng']],
          });
        } else {
          throw Exception('API Error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting place details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text("Search Destination"),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                // הוסף דיליי קטן כדי לא לשלוח יותר מדי בקשות
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _searchPlaces(value);
                  }
                });
              },
              decoration: InputDecoration(
                hintText: "Search for places, streets, addresses...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon:
                    _isLoading
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal,
                            ),
                          ),
                        )
                        : _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _predictions = [];
                            });
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Results list
          Expanded(
            child:
                _predictions.isEmpty
                    ? const Center(
                      child: Text(
                        "Start typing to search for places",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.teal,
                            ),
                            title: Text(
                              prediction['structured_formatting']?['main_text'] ??
                                  prediction['description'] ??
                                  'Unknown place',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              prediction['structured_formatting']?['secondary_text'] ??
                                  '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              _getPlaceDetails(
                                prediction['place_id'] ?? '',
                                prediction['description'] ?? 'Unknown place',
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
