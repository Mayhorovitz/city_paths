import 'package:flutter/material.dart';

class RouteResultsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  final String destinationAddress;

  const RouteResultsScreen({
    super.key,
    required this.routes,
    required this.destinationAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          'Route Results',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Destination info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To: $destinationAddress',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${routes.length} routes found',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Routes list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return _buildRouteCard(context, route, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context,
    Map<String, dynamic> route,
    int index,
  ) {
    final safetyRating = route['score'] ?? 0;
    final walkingTime = route['walkingTime']?['minutes'] ?? 0;
    final distance = route['distance']?['text'] ?? '';

    // Safety color based on score
    Color safetyColor = _getSafetyColor(safetyRating);
    IconData safetyIcon = _getSafetyIcon(safetyRating);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with safety rating
            Row(
              children: [
                Icon(safetyIcon, color: safetyColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Safety Rating: $safetyRating%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: safetyColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time and Distance
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$walkingTime min',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(Icons.location_on, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Safety indicators
            Row(
              children: [
                _buildSafetyIndicator(
                  'Lighting',
                  (route['lightingScore'] ?? 0).toDouble(),
                  Colors.blue,
                ),
                const SizedBox(width: 20),
                _buildSafetyIndicator(
                  'Crime',
                  (route['crimeScore'] ?? 0).toDouble(),
                  Colors.red,
                ),
                const SizedBox(width: 20),
                _buildSafetyIndicator(
                  'Businesses',
                  (route['businessScore'] ?? 0).toDouble(),
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Select Route Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'action': 'select',
                        'route': route,
                      });
                    },
                    child: const Text(
                      'Select Route',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'action': 'navigate',
                        'route': route,
                      });
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Navigate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyIndicator(String title, double score, Color color) {
    int fullTriangles =
        (score / 20).floor(); // 5 triangles max, each represents 20%

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 12,
                  color: index < fullTriangles ? color : color.withOpacity(0.3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Color _getSafetyColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getSafetyIcon(int score) {
    if (score >= 80) return Icons.shield;
    if (score >= 60) return Icons.warning_amber;
    return Icons.warning;
  }
}
