// lib/services/map_report_service.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:city_path/services/report_service.dart';
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
        radiusKm: radiusKm,
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
            icon: _getReportMarkerIcon(report['category']),
            infoWindow: InfoWindow(
              title: _getCategoryDisplayName(report['category']),
              snippet:
                  '${report['description']}\n${_formatReportTime(report['createdAt'])}',
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

  static BitmapDescriptor _getReportMarkerIcon(String category) {
    switch (category) {
      case 'poor_lighting':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case 'suspicious_gathering':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case 'road_hazard':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'violence_assault':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'harassment':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case 'police_security':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
    }
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
        if (report['description'] != null && report['description'].isNotEmpty)
          Text(
            report['description'],
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
          Row(
            children: [
              _buildInfoChip('Urgency', report['urgencyLevel'] ?? 'medium'),
              const SizedBox(width: 8),
              _buildInfoChip('Upvotes', '${report['upvotes'] ?? 0}'),
              const SizedBox(width: 8),
              _buildInfoChip('Downvotes', '${report['downvotes'] ?? 0}'),
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
