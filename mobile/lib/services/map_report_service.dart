// lib/services/map_report_service.dart - Updated with reputation display

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:city_path/services/report_service.dart';
import 'package:city_path/services/auth_service.dart';
import 'package:city_path/utils.dart';

class MapReportService {
  static Future<Set<Marker>> getReportMarkersNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required Function(Map<String, dynamic>) onReportTap,
  }) async {
    try {
      final result = await ReportService.getReportsNearby(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm.round().toDouble(),
      );

      if (result['success']) {
        final reports = List<Map<String, dynamic>>.from(
          result['reports'] ?? [],
        );
        return reports.map((report) {
          return Marker(
            markerId: MarkerId('report_${report['id']}'),
            position: LatLng(
              report['latitude'].toDouble(),
              report['longitude'].toDouble(),
            ),
            icon: _getReportMarkerIcon(
              report['category'],
              report['reporterBadge'] ?? 'newcomer',
            ),
            infoWindow: InfoWindow(
              title: _getCategoryDisplayName(report['category']),
              snippet:
                  '${report['description']}\n${_formatReportTime(report['createdAt'])}\nBy: ${_getReporterInfo(report)}',
              onTap: () => onReportTap(report),
            ),
          );
        }).toSet();
      }
    } catch (e) {
      print("Error loading report markers: $e");
    }

    return <Marker>{};
  }

  static BitmapDescriptor _getReportMarkerIcon(
    String category,
    String badgeLevel,
  ) {
    // Use different marker colors based on reporter's badge level
    double hue = BitmapDescriptor.hueOrange;

    switch (category) {
      case 'poor_lighting':
        hue = BitmapDescriptor.hueYellow;
        break;
      case 'suspicious_gathering':
        hue = BitmapDescriptor.hueOrange;
        break;
      case 'road_hazard':
        hue = BitmapDescriptor.hueRed;
        break;
      case 'violence_assault':
        hue = BitmapDescriptor.hueRed;
        break;
      case 'harassment':
        hue = BitmapDescriptor.hueViolet;
        break;
      case 'police_security':
        hue = BitmapDescriptor.hueBlue;
        break;
    }

    // Adjust saturation based on reporter's reputation
    // Higher reputation = more saturated/bright marker
    switch (badgeLevel) {
      case 'expert':
        // Keep full saturation for expert reporters
        break;
      case 'trusted':
        // Slightly less saturated for trusted
        break;
      case 'regular':
        // Regular saturation
        break;
      case 'newcomer':
        // Lower saturation for newcomers
        hue = hue * 0.8;
        break;
    }

    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  static String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'poor_lighting':
        return 'Poor Lighting';
      case 'suspicious_gathering':
        return 'Suspicious Activity';
      case 'road_hazard':
        return 'Road Hazard';
      case 'violence_assault':
        return 'Violence/Assault';
      case 'harassment':
        return 'Harassment';
      case 'police_security':
        return 'Security Presence';
      default:
        return 'Report';
    }
  }

  static String _getReporterInfo(Map<String, dynamic> report) {
    final name = report['reporterName'] ?? 'Anonymous';
    final badge = report['reporterBadge'] ?? 'newcomer';
    final reputation = report['reporterReputation'] ?? 0;

    return '$name (${AuthService.getBadgeDisplayName(badge)} - $reputation pts)';
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'poor_lighting':
        return Colors.amber;
      case 'suspicious_gathering':
        return Colors.orange;
      case 'road_hazard':
        return Colors.red;
      case 'violence_assault':
        return Colors.red[700]!;
      case 'harassment':
        return Colors.deepOrange;
      case 'police_security':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'poor_lighting':
        return Icons.lightbulb_outline;
      case 'suspicious_gathering':
        return Icons.group;
      case 'road_hazard':
        return Icons.warning;
      case 'violence_assault':
        return Icons.dangerous;
      case 'harassment':
        return Icons.report_problem;
      case 'police_security':
        return Icons.security;
      default:
        return Icons.report;
    }
  }

  static String _formatReportTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  static void showReportDetailsBottomSheet({
    required BuildContext context,
    required Map<String, dynamic> report,
    bool isInNavigation = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: !isInNavigation,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child:
                isInNavigation
                    ? _buildCompactReportDetails(context, report)
                    : _buildFullReportDetails(context, report),
          ),
    );
  }

  static Widget _buildCompactReportDetails(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: getCategoryColor(report['category']),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                getCategoryIcon(report['category']),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCategoryDisplayName(report['category']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatReportTime(report['createdAt']),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Reporter Info with Reputation
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                AuthService.getBadgeIcon(report['reporterBadge'] ?? 'newcomer'),
                color: AuthService.getBadgeColor(
                  report['reporterBadge'] ?? 'newcomer',
                ),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _getReporterInfo(report),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (report['description'] != null && report['description'].isNotEmpty)
          Text(
            report['description'],
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        const SizedBox(height: 16),

        // Voting Section
        _buildVotingSection(context, report),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Future: Add avoid area functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Avoid Area'),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildFullReportDetails(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: getCategoryColor(report['category']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getCategoryIcon(report['category']),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCategoryDisplayName(report['category']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatReportTime(report['createdAt']),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Reporter Info Card
          Card(
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    AuthService.getBadgeIcon(
                      report['reporterBadge'] ?? 'newcomer',
                    ),
                    color: AuthService.getBadgeColor(
                      report['reporterBadge'] ?? 'newcomer',
                    ),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report['reporterName'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${AuthService.getBadgeDisplayName(report['reporterBadge'] ?? 'newcomer')} • ${report['reporterReputation'] ?? 0} points',
                        style: TextStyle(
                          fontSize: 12,
                          color: AuthService.getBadgeColor(
                            report['reporterBadge'] ?? 'newcomer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Description',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            report['description'] ?? 'No description provided',
            style: const TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 16),

          // Voting Section
          _buildVotingSection(context, report),

          const SizedBox(height: 16),

          Row(
            children: [
              _buildInfoChip('Urgency', report['urgencyLevel'] ?? 'medium'),
              const SizedBox(width: 8),
              _buildInfoChip('Verified', report['isVerified'] ? 'Yes' : 'No'),
            ],
          ),

          if (report['imagePath'] != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${ApiConfig.baseUrl}${report['imagePath']}',
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildVotingSection(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () => _handleVote(context, report, true),
            child: Column(
              children: [
                Icon(Icons.thumb_up, color: Colors.green, size: 24),
                Text('${report['upvotes'] ?? 0}'),
                Text('Helpful', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _handleVote(context, report, false),
            child: Column(
              children: [
                Icon(Icons.thumb_down, color: Colors.red, size: 24),
                Text('${report['downvotes'] ?? 0}'),
                Text('Not Helpful', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _handleVote(
    BuildContext context,
    Map<String, dynamic> report,
    bool isUpvote,
  ) async {
    try {
      final result = await ReportService.voteOnReport(
        reportId: report['id'].toString(),
        isUpvote: isUpvote,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote recorded! ${result['message'] ?? ''}'),
            backgroundColor: Colors.green,
          ),
        );

        // Show reputation update if available
        if (result['reputationUpdate'] != null) {
          final repUpdate = result['reputationUpdate'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reporter gained ${repUpdate['reputationChange']} reputation points!',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }

        Navigator.pop(context); // Close the bottom sheet
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to vote'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error voting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
