import 'package:flutter/material.dart';

class RouteResultsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  final String destinationAddress;
  final Map<String, dynamic>? scoringInfo;

  const RouteResultsScreen({
    super.key,
    required this.routes,
    required this.destinationAddress,
    this.scoringInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          'Routes',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header with destination and preferences info
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
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${routes.length} routes found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (scoringInfo != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        scoringInfo!['preferencesSource'] == 'user_profile'
                            ? Icons.person
                            : Icons.public,
                        size: 14,
                        color:
                            scoringInfo!['preferencesSource'] == 'user_profile'
                                ? Colors.blue
                                : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          scoringInfo!['message'] ?? 'Routes calculated',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                scoringInfo!['preferencesSource'] ==
                                        'user_profile'
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Preferences info banner (if using user preferences)
          if (scoringInfo?['preferencesSource'] == 'user_profile')
            _buildPreferencesBanner(),

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

  Widget _buildPreferencesBanner() {
    if (scoringInfo == null || scoringInfo!['preferencesUsed'] == null) {
      return const SizedBox.shrink();
    }

    final prefs = scoringInfo!['preferencesUsed'] as Map<String, dynamic>;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text(
                'Routes calculated using your preferences',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPrefChip('💡 ${prefs['lighting']}', Colors.amber),
              _buildPrefChip('🏪 ${prefs['business']}', Colors.green),
              _buildPrefChip('🛡️ ${prefs['crime']}', Colors.red),
              _buildPrefChip('📢 ${prefs['reports']}', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrefChip(String text, Color color) {
    Color darkColor;
    switch (color) {
      case Colors.amber:
        darkColor = Colors.amber[700]!;
        break;
      case Colors.green:
        darkColor = Colors.green[700]!;
        break;
      case Colors.red:
        darkColor = Colors.red[700]!;
        break;
      case Colors.blue:
        darkColor = Colors.blue[700]!;
        break;
      default:
        darkColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: darkColor,
        ),
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

    Color safetyColor = _getSafetyColor(safetyRating);
    IconData safetyIcon = _getSafetyIcon(safetyRating);

    // Check if this route has user preferences applied
    final hasUserPrefs = route['preferencesSource'] == 'user_profile';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with safety score and personalization indicator
            Row(
              children: [
                Icon(safetyIcon, color: safetyColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety: $safetyRating%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: safetyColor,
                        ),
                      ),
                      if (hasUserPrefs)
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Personalized for you',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (index == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Time and distance
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$walkingTime min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.straighten, color: Colors.green, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Safety indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSafetyIndicator(
                  'Lighting',
                  (route['lightingScore'] ?? 0).toDouble(),
                  Colors.amber,
                  Icons.lightbulb,
                ),
                _buildSafetyIndicator(
                  'Business',
                  (route['businessScore'] ?? 0).toDouble(),
                  Colors.green,
                  Icons.store,
                ),
                _buildSafetyIndicator(
                  'Crime',
                  (route['crimeScore'] ?? 0).toDouble(),
                  Colors.red,
                  Icons.security,
                ),
                _buildSafetyIndicator(
                  'Reports',
                  (route['reportsScore'] ?? 0).toDouble(),
                  Colors.blue,
                  Icons.report,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
                        Icon(Icons.navigation, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Navigate',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Widget _buildSafetyIndicator(
    String title,
    double score,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${score.round()}%',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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
