import 'package:flutter/material.dart';
import 'package:city_path/screens/home_screen.dart';
import 'package:city_path/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedDate;

  // Preference variables
  double _lightingPreference = 0.30;
  double _businessPreference = 0.25;
  double _crimePreference = 0.20;
  double _reportsPreference = 0.25;

  String _selectedPreset = 'balanced';
  bool _showAdvancedPreferences = false;

  final Map<String, Map<String, double>> _presets = {
    'balanced': {
      'lighting': 0.30,
      'business': 0.25,
      'crime': 0.20,
      'reports': 0.25,
    },
    'lighting_focused': {
      'lighting': 0.70,
      'business': 0.15,
      'crime': 0.10,
      'reports': 0.05,
    },
    'business_focused': {
      'lighting': 0.20,
      'business': 0.60,
      'crime': 0.10,
      'reports': 0.10,
    },
    'crime_focused': {
      'lighting': 0.25,
      'business': 0.15,
      'crime': 0.50,
      'reports': 0.10,
    },
    'community_focused': {
      'lighting': 0.20,
      'business': 0.20,
      'crime': 0.10,
      'reports': 0.50,
    },
  };

  void _applyPreset(String preset) {
    if (_presets.containsKey(preset)) {
      setState(() {
        _selectedPreset = preset;
        _lightingPreference = _presets[preset]!['lighting']!;
        _businessPreference = _presets[preset]!['business']!;
        _crimePreference = _presets[preset]!['crime']!;
        _reportsPreference = _presets[preset]!['reports']!;
      });
    }
  }

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

  void _updatePreferenceFromSlider(String type, double value) {
    setState(() {
      switch (type) {
        case 'lighting':
          _lightingPreference = value;
          break;
        case 'business':
          _businessPreference = value;
          break;
        case 'crime':
          _crimePreference = value;
          break;
        case 'reports':
          _reportsPreference = value;
          break;
      }
      _selectedPreset = 'custom'; // Mark as custom when manually adjusted
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(
        const Duration(days: 365 * 13),
      ), // At least 13 years old
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Normalize preferences to ensure they sum to 1.0
    _normalizePreferences();

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.registerUser(
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _selectedDate != null ? _dateOfBirthController.text : null,
        lightingPreference: _lightingPreference,
        businessPreference: _businessPreference,
        crimePreference: _crimePreference,
        reportsPreference: _reportsPreference,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        _showSnackBar(
          result['message'] ?? "Registration successful!",
          isError: false,
        );

        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        String message = result['message'] ?? 'Registration failed';
        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('An error occurred. Please try again.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004d71),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004d71),
                  ),
                ),

                const SizedBox(height: 20),

                // First Name and Last Name row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Date of Birth
                TextFormField(
                  controller: _dateOfBirthController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth (Optional)',
                    hintText: 'Tap to select date',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004d71),
                  ),
                ),

                const SizedBox(height: 16),

                // Phone number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '05X-XXXXXXX',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    if (!AuthService.isValidPhone(value)) {
                      return 'Please enter a valid Israeli phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'your@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!AuthService.isValidEmail(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                const Text(
                  'Security',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004d71),
                  ),
                ),

                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    hintText: 'At least 6 characters',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (!AuthService.isValidPassword(value)) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    hintText: 'Enter password again',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Safety Preferences Section
                _buildPreferencesSection(),

                const SizedBox(height: 32),

                // Register button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004d71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 16),

                // Login link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFF004d71),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Safety Priorities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF004d71),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Customize how routes are calculated based on your safety priorities',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Preset selection
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedPreset,
            decoration: const InputDecoration(
              labelText: 'Choose a preset',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'balanced',
                child: Text(AuthService.getPresetDisplayName('balanced')),
              ),
              DropdownMenuItem(
                value: 'lighting_focused',
                child: Text(
                  AuthService.getPresetDisplayName('lighting_focused'),
                ),
              ),
              DropdownMenuItem(
                value: 'business_focused',
                child: Text(
                  AuthService.getPresetDisplayName('business_focused'),
                ),
              ),
              DropdownMenuItem(
                value: 'crime_focused',
                child: Text(AuthService.getPresetDisplayName('crime_focused')),
              ),
              DropdownMenuItem(
                value: 'community_focused',
                child: Text(
                  AuthService.getPresetDisplayName('community_focused'),
                ),
              ),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value != null && value != 'custom') {
                _applyPreset(value);
              }
            },
          ),
        ),

        const SizedBox(height: 16),

        // Show current distribution
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
              const Text(
                'Current Distribution:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDistributionChip(
                    'Lighting',
                    _lightingPreference,
                    Colors.amber,
                  ),
                  _buildDistributionChip(
                    'Business',
                    _businessPreference,
                    Colors.green,
                  ),
                  _buildDistributionChip('Crime', _crimePreference, Colors.red),
                  _buildDistributionChip(
                    'Reports',
                    _reportsPreference,
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Advanced preferences toggle
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showAdvancedPreferences = !_showAdvancedPreferences;
            });
          },
          icon: Icon(
            _showAdvancedPreferences ? Icons.expand_less : Icons.expand_more,
          ),
          label: Text(
            _showAdvancedPreferences
                ? 'Hide Advanced Settings'
                : 'Show Advanced Settings',
          ),
        ),

        // Advanced sliders
        if (_showAdvancedPreferences) ...[
          const SizedBox(height: 16),
          _buildPreferenceSlider(
            'Street Lighting',
            _lightingPreference,
            Icons.lightbulb_outline,
            Colors.amber,
            (value) => _updatePreferenceFromSlider('lighting', value),
          ),
          _buildPreferenceSlider(
            'Open Businesses',
            _businessPreference,
            Icons.store,
            Colors.green,
            (value) => _updatePreferenceFromSlider('business', value),
          ),
          _buildPreferenceSlider(
            'Crime Avoidance',
            _crimePreference,
            Icons.security,
            Colors.red,
            (value) => _updatePreferenceFromSlider('crime', value),
          ),
          _buildPreferenceSlider(
            'Community Reports',
            _reportsPreference,
            Icons.people,
            Colors.blue,
            (value) => _updatePreferenceFromSlider('reports', value),
          ),

          const SizedBox(height: 16),

          // Auto-normalize button
          Center(
            child: ElevatedButton.icon(
              onPressed: _normalizePreferences,
              icon: const Icon(Icons.balance, size: 18),
              label: const Text('Auto-Balance Preferences'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDistributionChip(String label, double value, Color color) {
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: darkColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPreferenceSlider(
    String title,
    double value,
    IconData icon,
    Color color,
    Function(double) onChanged,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    color: darkColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                inactiveTrackColor: color.withValues(alpha: 0.3),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getPreferenceDescription(title),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getPreferenceDescription(String title) {
    switch (title) {
      case 'Street Lighting':
        return 'Prioritize well-lit streets and avoid dark areas';
      case 'Open Businesses':
        return 'Prefer routes with active businesses and foot traffic';
      case 'Crime Avoidance':
        return 'Avoid areas with reported criminal activity';
      case 'Community Reports':
        return 'Consider real-time safety reports from other users';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }
}
