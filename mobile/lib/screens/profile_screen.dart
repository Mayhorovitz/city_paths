// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:city_path/services/auth_service.dart';
import 'package:city_path/services/report_service.dart';
import '../utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _reputationDetails;
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Profile, 1: Reputation, 2: Leaderboard

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Load user profile
      final profileResult = await AuthService.getUserProfile();
      if (profileResult['success']) {
        _userProfile = profileResult['user'];
      }

      // Load reputation details
      final reputationResult = await AuthService.getReputationDetails();
      if (reputationResult['success']) {
        _reputationDetails = reputationResult['reputationDetails'];
      }

      // Load leaderboard
      final leaderboardResult = await AuthService.getLeaderboard();
      if (leaderboardResult['success']) {
        _leaderboard = leaderboardResult['leaderboard'] ?? [];
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F2E9),
        appBar: AppBar(
          backgroundColor: Colors.teal,
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child:
                _selectedTab == 0
                    ? _buildProfileTab()
                    : _selectedTab == 1
                    ? _buildReputationTab()
                    : _buildLeaderboardTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTabButton('Profile', 0),
          _buildTabButton('Reputation', 1),
          _buildTabButton('Leaderboard', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.teal : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.teal : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_userProfile == null) {
      return const Center(child: Text('Failed to load profile'));
    }

    final reputation = _userProfile!['reputation'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User Info Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Picture & Name
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.teal.withOpacity(0.2),
                    child: Text(
                      '${_userProfile!['firstName'][0]}${_userProfile!['lastName'][0]}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_userProfile!['firstName']} ${_userProfile!['lastName']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AuthService.getBadgeColor(
                        reputation['badgeLevel'] ?? 'newcomer',
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AuthService.getBadgeIcon(
                            reputation['badgeLevel'] ?? 'newcomer',
                          ),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AuthService.getBadgeDisplayName(
                            reputation['badgeLevel'] ?? 'newcomer',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reputation Score Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reputation Score',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${reputation['score'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const Text('Points'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${reputation['totalReports'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text('Reports'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${reputation['verifiedReports'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text('Verified'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Badges Card
          if (_userProfile!['badges'] != null &&
              _userProfile!['badges'].isNotEmpty)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Badges Earned',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(_userProfile!['badges'] as List).map(
                      (badge) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              AuthService.getBadgeIcon(badge['badge_type']),
                              color: AuthService.getBadgeColor(
                                badge['badge_type'],
                              ),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    badge['badge_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    badge['description'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Recent Activity Card
          if (_userProfile!['recentActivity'] != null &&
              _userProfile!['recentActivity'].isNotEmpty)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(_userProfile!['recentActivity'] as List)
                        .take(5)
                        .map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color:
                                        activity['reputation_change'] > 0
                                            ? Colors.green
                                            : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activity['reason'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        '${activity['reputation_change'] > 0 ? '+' : ''}${activity['reputation_change']} points',
                                        style: TextStyle(
                                          color:
                                              activity['reputation_change'] > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReputationTab() {
    print('=== DEBUG REPUTATION TAB ===');
    print('_reputationDetails is null: ${_reputationDetails == null}');

    if (_reputationDetails != null) {
      print('nextBadge: ${_reputationDetails!['nextBadge']}');
      print('pointsToNext: ${_reputationDetails!['pointsToNext']}');
      print('breakdown: ${_reputationDetails!['breakdown']}');
      print('breakdown type: ${_reputationDetails!['breakdown'].runtimeType}');
    }

    if (_reputationDetails == null) {
      return const Center(child: Text('Failed to load reputation details'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress to Next Badge
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badge Progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_reputationDetails!['nextBadge'] != null) ...[
                    Text(
                      'Next: ${AuthService.getBadgeDisplayName(_reputationDetails!['nextBadge'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _calculateProgressValue(),
                      backgroundColor: Colors.grey[300],
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_reputationDetails!['pointsToNext']} points to go!',
                    ),
                  ] else ...[
                    const Text('🎉 You\'ve reached the highest badge level!'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reputation Breakdown
          if (_reputationDetails!['breakdown'] != null &&
              _reputationDetails!['breakdown'].isNotEmpty)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Points Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(_reputationDetails!['breakdown'] as List).map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_getActionDisplayName(item['action_type'])),
                            Text(
                              '${item['total_points'] > 0 ? '+' : ''}${item['total_points']} pts',
                              style: TextStyle(
                                color:
                                    item['total_points'] > 0
                                        ? Colors.green
                                        : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    if (_leaderboard.isEmpty) {
      return const Center(child: Text('No leaderboard data available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final user = _leaderboard[index];
        final isCurrentUser =
            _userProfile != null &&
            user['name'].startsWith(
              '${_userProfile!['firstName']} ${_userProfile!['lastName'][0]}',
            );

        return Card(
          elevation: isCurrentUser ? 6 : 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isCurrentUser ? Colors.teal.withOpacity(0.1) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getRankColor(user['rank']),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${user['rank']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCurrentUser ? Colors.teal : null,
                        ),
                      ),
                      Text(
                        AuthService.getBadgeDisplayName(user['badgeLevel']),
                        style: TextStyle(
                          color: AuthService.getBadgeColor(user['badgeLevel']),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${user['reputationScore']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    Text(
                      '${user['totalReports']} reports',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getActionDisplayName(String actionType) {
    switch (actionType) {
      case 'REPORT_CREATED':
        return 'Created Reports';
      case 'VOTE_RECEIVED_UP':
        return 'Received Upvotes';
      case 'VOTE_RECEIVED_DOWN':
        return 'Received Downvotes';
      case 'REPORT_VERIFIED':
        return 'Verified Reports';
      case 'HELPFUL_VOTE_GIVEN':
        return 'Helpful Votes Given';
      default:
        return actionType.replaceAll('_', ' ');
    }
  }

  double _calculateProgressValue() {
    try {
      if (_reputationDetails == null ||
          _reputationDetails!['nextBadge'] == null) {
        return 1.0;
      }

      final pointsToNext =
          (_reputationDetails!['pointsToNext'] ?? 0).toDouble();
      final currentBadge = _reputationDetails!['currentBadge'];
      final nextBadge = _reputationDetails!['nextBadge'];
      final badgeThresholds = _reputationDetails!['badgeThresholds'];

      if (badgeThresholds == null ||
          badgeThresholds[currentBadge] == null ||
          badgeThresholds[nextBadge] == null) {
        return 0.5;
      }

      final currentThreshold =
          (badgeThresholds[currentBadge]['threshold'] ?? 0).toDouble();
      final nextThreshold =
          (badgeThresholds[nextBadge]['threshold'] ?? 0).toDouble();
      final totalGap = nextThreshold - currentThreshold;

      if (totalGap <= 0) return 1.0;

      return (1.0 - (pointsToNext / totalGap)).clamp(0.0, 1.0);
    } catch (e) {
      print('Error calculating progress: $e');
      return 0.0;
    }
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey[400]!;
    if (rank == 3) return Colors.brown;
    return Colors.teal;
  }
}
