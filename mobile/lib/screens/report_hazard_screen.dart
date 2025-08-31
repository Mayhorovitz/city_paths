import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:city_path/services/report_service.dart';

class ReportHazardScreen extends StatefulWidget {
  const ReportHazardScreen({super.key});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  String? _selectedCategory;
  String _urgencyLevel = 'Medium';
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  Position? _currentLocation;
  bool _isLoading = false;
  bool _isLocationLoading = true;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'poor_lighting',
      'title': 'Poor Lighting',
      'subtitle': 'Broken street lights, dark areas',
      'icon': Icons.lightbulb_outline,
      'color': Colors.amber,
    },
    {
      'id': 'suspicious_gathering',
      'title': 'Suspicious Gathering',
      'subtitle': 'Unusual groups or activities',
      'icon': Icons.group,
      'color': Colors.orange,
    },
    {
      'id': 'road_hazard',
      'title': 'Road Hazard',
      'subtitle': 'Obstacles, construction, damaged roads',
      'icon': Icons.warning,
      'color': Colors.red,
    },
    {
      'id': 'violence_assault',
      'title': 'Violence/Assault',
      'subtitle': 'Violent incidents or threats',
      'icon': Icons.dangerous,
      'color': Colors.red.shade700,
    },
    {
      'id': 'harassment',
      'title': 'Harassment',
      'subtitle': 'Unwanted attention or following',
      'icon': Icons.report_problem,
      'color': Colors.deepOrange,
    },
    {
      'id': 'police_security',
      'title': 'Police/Security Presence',
      'subtitle': 'Positive security presence',
      'icon': Icons.security,
      'color': Colors.blue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLocationLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = position;
        _isLocationLoading = false;
      });
    } catch (e) {
      print("Error getting location: $e");
      setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Add Photo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),
                if (_selectedImage != null)
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Remove Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      _showSnackBar('Please select a category', isError: true);
      return;
    }

    if (_currentLocation == null) {
      _showSnackBar('Location not available. Please try again.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ReportService.submitReport(
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        urgencyLevel: _urgencyLevel.toLowerCase(),
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        image: _selectedImage,
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        _showSnackBar('Report submitted successfully!', isError: false);
        Navigator.pop(context, true); // Return success
      } else {
        _showSnackBar(
          result['message'] ?? 'Failed to submit report',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error submitting report: $e', isError: true);
    }
  }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          'Report a Hazard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories Section
              const Text(
                'What happened?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              ..._categories.map((category) => _buildCategoryCard(category)),

              const SizedBox(height: 24),

              // Description Section
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe what you observed...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),

              // Photo Section
              const Text(
                'Add Photo (optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: _selectedImage != null ? 200 : 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child:
                      _selectedImage != null
                          ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImage!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap:
                                      () =>
                                          setState(() => _selectedImage = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                          : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to add photo',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                ),
              ),

              const SizedBox(height: 24),

              // Urgency Level Section
              const Text(
                'Urgency Level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children:
                    ['Low', 'Medium', 'High'].map((level) {
                      final isSelected = _urgencyLevel == level;
                      Color color = Colors.green;
                      if (level == 'Medium') color = Colors.orange;
                      if (level == 'High') color = Colors.red;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _urgencyLevel = level),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? color : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isSelected ? color : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              level,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 24),

              // Location Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _isLocationLoading
                                ? 'Getting current location...'
                                : _currentLocation != null
                                ? 'Current location detected'
                                : 'Location not available',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLocationLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_currentLocation == null)
                      IconButton(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _submitReport,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Submit Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final isSelected = _selectedCategory == category['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category['id']),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isSelected ? category['color'].withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? category['color'] : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: category['color'].withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category['color'].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  category['icon'],
                  color: category['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? category['color'] : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category['subtitle'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: category['color'], size: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
