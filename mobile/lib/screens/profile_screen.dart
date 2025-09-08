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
  int _selectedTab =
      0; // 0: Profile, 1: Reputation, 2: Preferences, 3: Leaderboard

  // Preferences editing state
  bool _isEditingPreferences = false;
  double _lightingPreference = 0.30;
  double _businessPreference = 0.25;
  double _crimePreference = 0.20;
  double _reportsPreference = 0.25;
  bool _isSavingPreferences = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Debug function to print detailed user data information
  void _debugUserData() {
    print("=== DEBUG USER DATA ===");
    print("_userProfile: $_userProfile");
    print("_userProfile type: ${_userProfile.runtimeType}");

    if (_userProfile != null) {
      print("Keys in _userProfile: ${_userProfile!.keys.toList()}");
      print("preferences value: ${_userProfile!['preferences']}");
      print("preferences type: ${_userProfile!['preferences'].runtimeType}");
    }
    print("========================");
  }

  /// Load all user data including profile, reputation, and leaderboard
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Load user profile with detailed debugging
      final profileResult = await AuthService.getUserProfile();
      print("=== Profile Result ===");
      print("Success: ${profileResult['success']}");
      print("User data: ${profileResult['user']}");

      if (profileResult['success']) {
        _userProfile = profileResult['user'];

        // Check if preferences exist in response
        if (_userProfile!['preferences'] != null) {
          final prefs = _userProfile!['preferences'];
          print("Found preferences in profile: $prefs");

          // Ensure values are converted to doubles safely
          _lightingPreference = (prefs['lighting'] ?? 0.30).toDouble();
          _businessPreference = (prefs['business'] ?? 0.25).toDouble();
          _crimePreference = (prefs['crime'] ?? 0.20).toDouble();
          _reportsPreference = (prefs['reports'] ?? 0.25).toDouble();

          print(
            "Loaded preferences: L:$_lightingPreference B:$_businessPreference C:$_crimePreference R:$_reportsPreference",
          );
        } else {
          print("No preferences found in user profile, creating defaults");
          // Create default preferences if they don't exist
          _userProfile!['preferences'] = {
            'lighting': 0.30,
            'business': 0.25,
            'crime': 0.20,
            'reports': 0.25,
          };
        }
      } else {
        print("Failed to load profile: ${profileResult['message']}");
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

  /// Save updated preferences to the server
  Future<void> _savePreferences() async {
    setState(() => _isSavingPreferences = true);

    try {
      final result = await AuthService.updatePreferences(
        lightingPreference: _lightingPreference,
        businessPreference: _businessPreference,
        crimePreference: _crimePreference,
        reportsPreference: _reportsPreference,
      );

      if (result['success']) {
        // Update local user profile with new preferences
        setState(() {
          _userProfile!['preferences'] = {
            'lighting': _lightingPreference,
            'business': _businessPreference,
            'crime': _crimePreference,
            'reports': _reportsPreference,
          };
          _isEditingPreferences = false;
        });

        _showSnackBar('Preferences updated successfully!', isError: false);
      } else {
        _showSnackBar(
          result['message'] ?? 'Failed to update preferences',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error updating preferences: $e', isError: true);
    } finally {
      setState(() => _isSavingPreferences = false);
    }
  }

  /// Normalize preferences so they add up to 1.0
  void _normalizePreferences() {
    final total =
        _lightingPreference +
        _businessPreference +
        _crimePreference +
        _reportsPreference;
    if (total > 0) {
      setState(() {
        _lightingPreference /= total;
        _businessPreference /= total;
        _crimePreference /= total;
        _reportsPreference /= total;
      });
    }
  }

  /// Show snackbar with success or error message
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                    : _selectedTab == 2
                    ? _buildPreferencesTab()
                    : _buildLeaderboardTab(),
          ),
        ],
      ),
    );
  }

  /// Build the tab navigation bar
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTabButton('Profile', 0),
          _buildTabButton('Reputation', 1),
          _buildTabButton('Preferences', 2),
          _buildTabButton('Leaderboard', 3),
        ],
      ),
    );
  }

  /// Build individual tab button
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Build the preferences tab with improved error handling
  Widget _buildPreferencesTab() {
    // Debug output for troubleshooting
    _debugUserData();

    // Enhanced validation checks
    if (_userProfile == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('User profile not loaded'),
          ],
        ),
      );
    }

    // Check if preferences exist
    final preferences = _userProfile!['preferences'];
    print("Checking preferences: $preferences");

    if (preferences == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No preferences data available'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Try to reload data
                _loadUserData();
              },
              child: const Text('Reload Data'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Create default preferences
                setState(() {
                  _userProfile!['preferences'] = {
                    'lighting': 0.30,
                    'business': 0.25,
                    'crime': 0.20,
                    'reports': 0.25,
                  };
                });
              },
              child: const Text('Use Default Preferences'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safety Preferences',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (!_isEditingPreferences)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditingPreferences = true),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isEditingPreferences) ...[
            // Editing mode
            _buildEditingPreferences(),
          ] else ...[
            // Display mode
            _buildDisplayPreferences(),
          ],
        ],
      ),
    );
  }

  /// Build the display view for preferences (read-only)
  Widget _buildDisplayPreferences() {
    final prefs = _userProfile!['preferences'];

    return Column(
      children: [
        // Current distribution visualization
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Route Calculation Priorities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Visual preference bars
              _buildPreferenceBar(
                'Street Lighting',
                prefs['lighting'],
                Colors.amber,
                Icons.lightbulb_outline,
              ),
              const SizedBox(height: 12),
              _buildPreferenceBar(
                'Open Businesses',
                prefs['business'],
                Colors.green,
                Icons.store,
              ),
              const SizedBox(height: 12),
              _buildPreferenceBar(
                'Crime Avoidance',
                prefs['crime'],
                Colors.red,
                Icons.security,
              ),
              const SizedBox(height: 12),
              _buildPreferenceBar(
                'Community Reports',
                prefs['reports'],
                Colors.blue,
                Icons.people,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Information card explaining how preferences work
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'How This Works',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'These preferences determine how safety scores are calculated for your routes. Higher percentages mean that factor is more important in route selection.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a visual preference bar showing percentage and progress
  Widget _buildPreferenceBar(
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    final percentage = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${percentage}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the editing interface for preferences
  Widget _buildEditingPreferences() {
    return Column(
      children: [
        // Preference sliders
        _buildPreferenceSlider(
          'Street Lighting',
          _lightingPreference,
          Icons.lightbulb_outline,
          Colors.amber,
          (value) => setState(() => _lightingPreference = value),
        ),
        _buildPreferenceSlider(
          'Open Businesses',
          _businessPreference,
          Icons.store,
          Colors.green,
          (value) => setState(() => _businessPreference = value),
        ),
        _buildPreferenceSlider(
          'Crime Avoidance',
          _crimePreference,
          Icons.security,
          Colors.red,
          (value) => setState(() => _crimePreference = value),
        ),
        _buildPreferenceSlider(
          'Community Reports',
          _reportsPreference,
          Icons.people,
          Colors.blue,
          (value) => setState(() => _reportsPreference = value),
        ),

        const SizedBox(height: 20),

        // Auto-balance button to normalize preferences
        ElevatedButton.icon(
          onPressed: _normalizePreferences,
          icon: const Icon(Icons.balance, size: 18),
          label: const Text('Auto-Balance'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 20),

        // Action buttons (Cancel/Save)
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Reset to original values from profile
                  if (_userProfile!['preferences'] != null) {
                    final prefs = _userProfile!['preferences'];
                    setState(() {
                      _lightingPreference =
                          prefs['lighting']?.toDouble() ?? 0.30;
                      _businessPreference =
                          prefs['business']?.toDouble() ?? 0.25;
                      _crimePreference = prefs['crime']?.toDouble() ?? 0.20;
                      _reportsPreference = prefs['reports']?.toDouble() ?? 0.25;
                      _isEditingPreferences = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSavingPreferences ? null : _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isSavingPreferences
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build a preference slider with visual feedback
  Widget _buildPreferenceSlider(
    String title,
    double value,
    IconData icon,
    Color color,
    Function(double) onChanged,
  ) {
    // Determine dark color for better contrast
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      color: darkColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                inactiveTrackColor: color.withValues(alpha: 0.3),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the profile tab showing user information
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
                    backgroundColor: Colors.teal.withValues(alpha: 0.2),
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
                  // Badge display
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
        ],
      ),
    );
  }

  /// Build the reputation tab showing badge progress
  Widget _buildReputationTab() {
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
        ],
      ),
    );
  }

  /// Build the leaderboard tab showing top users
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
          color: isCurrentUser ? Colors.teal.withValues(alpha: 0.1) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank indicator
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
                // User information
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
                // Score and statistics
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

  /// Calculate progress value for badge advancement
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

  /// Get color for rank badge based on position
  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber; // Gold for first place
    if (rank == 2) return Colors.grey[400]!; // Silver for second place
    if (rank == 3) return Colors.brown; // Bronze for third place
    return Colors.teal; // Default color for other ranks
  }
}
