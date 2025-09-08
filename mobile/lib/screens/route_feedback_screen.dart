// lib/screens/route_feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:city_path/services/feedback_service.dart';
import 'package:city_path/screens/home_screen.dart';

class RouteFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> routeData;
  final String destinationAddress;
  final Duration actualDuration;
  final List<Map<String, dynamic>> encounteredReports;

  const RouteFeedbackScreen({
    super.key,
    required this.routeData,
    required this.destinationAddress,
    required this.actualDuration,
    required this.encounteredReports,
  });

  @override
  State<RouteFeedbackScreen> createState() => _RouteFeedbackScreenState();
}

class _RouteFeedbackScreenState extends State<RouteFeedbackScreen> {
  int _safetyRating = 0;
  bool _wouldUseAgain = true;
  final TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'How was your route?',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'You have arrived safely!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Destination: ${widget.destinationAddress}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Route summary
            _buildRouteSummary(),

            const SizedBox(height: 24),

            // Safety rating - Only question
            _buildRatingSection(
              'How safe did you feel during this route?',
              'Safety Rating',
              _safetyRating,
              (rating) => setState(() => _safetyRating = rating),
              ['Very unsafe', 'Unsafe', 'Neutral', 'Safe', 'Very safe'],
            ),

            const SizedBox(height: 24),

            // Would use again
            _buildBooleanSection(),

            const SizedBox(height: 24),

            // Comments
            _buildCommentsSection(),

            const SizedBox(height: 32),

            // Submit button
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // Skip button
            _buildSkipButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSummary() {
    final predictedScore = widget.routeData['score'] ?? 0;
    final duration = widget.actualDuration;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Predicted Safety',
                  '$predictedScore%',
                  _getSafetyColor(predictedScore),
                ),
                _buildSummaryItem(
                  'Duration',
                  '${duration.inMinutes}m',
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Reports Encountered',
                  '${widget.encounteredReports.length}',
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRatingSection(
    String question,
    String title,
    int currentRating,
    Function(int) onRatingChanged,
    List<String> labels,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final isSelected = currentRating == rating;

                return GestureDetector(
                  onTap: () => onRatingChanged(rating),
                  child: Column(
                    children: [
                      Icon(
                        isSelected ? Icons.star : Icons.star_border,
                        size: 32,
                        color: isSelected ? Colors.amber : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$rating',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.amber : Colors.grey,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            if (currentRating > 0) ...[
              const SizedBox(height: 8),
              Text(
                labels[currentRating - 1],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBooleanSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Would you use this route again?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wouldUseAgain = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _wouldUseAgain ? Colors.green : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _wouldUseAgain ? Colors.green : Colors.grey,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.thumb_up,
                            color: _wouldUseAgain ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yes',
                            style: TextStyle(
                              color:
                                  _wouldUseAgain ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wouldUseAgain = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !_wouldUseAgain ? Colors.red : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !_wouldUseAgain ? Colors.red : Colors.grey,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.thumb_down,
                            color: !_wouldUseAgain ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No',
                            style: TextStyle(
                              color:
                                  !_wouldUseAgain ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCommentsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Comments (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us more about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _safetyRating > 0; // Only check safety rating

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canSubmit ? Colors.green : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: canSubmit && !_isSubmitting ? _submitFeedback : null,
        child:
            _isSubmitting
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text(
                  'Submit Feedback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _skipFeedback,
        child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);

    try {
      await FeedbackService.submitRouteFeedback(
        routeData: widget.routeData,
        safetyRating: _safetyRating,
        accuracyRating: _safetyRating, // Send same rating as both values
        wouldUseAgain: _wouldUseAgain,
        comments: _commentsController.text,
        actualDuration: widget.actualDuration,
        encounteredReports: widget.encounteredReports,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
        _navigateHome();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _skipFeedback() {
    _navigateHome();
  }

  void _navigateHome() {
    // Remove all previous routes and navigate to HomeScreen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  Color _getSafetyColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }
}
