import 'package:flutter/material.dart';
import 'package:city_path/services/auth_service.dart';
import 'package:city_path/screens/home_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String phoneOrEmail;
  final bool isNewUser;
  final Map<String, dynamic>? user;

  const VerifyCodeScreen({
    super.key,
    required this.phoneOrEmail,
    this.isNewUser = false,
    this.user,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());
  bool _isLoading = false;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });
        _startResendTimer();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    // Use the new auth service methods
    Map<String, dynamic> result;
    if (widget.isNewUser) {
      // For new users, we need to extract phone and email
      final phone = widget.user?['phone'] ?? widget.phoneOrEmail;
      final email = widget.user?['email'] ?? widget.phoneOrEmail;
      result = await AuthService.registerUser(phone: phone, email: email);
    } else {
      result = await AuthService.loginUser(phoneOrEmail: widget.phoneOrEmail);
    }

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _canResend = false;
        _resendSeconds = 60;
        _startResendTimer();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success']
              ? "New code sent!"
              : result['message'] ?? "Error sending code",
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onCodeChanged(String value, int index) {
    if (value.length == 1) {
      // Move to next field
      if (index < 4) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Submit code when last digit is entered
        _verifyCode();
      }
    }
  }

  String _getFullCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyCode() async {
    final code = _getFullCode();

    if (code.length != 5) {
      _showSnackBar(
        "Please enter the 5-digit verification code",
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Extract phone from phoneOrEmail or user data
    String phone = widget.phoneOrEmail;
    if (widget.user != null && widget.user!['phone'] != null) {
      phone = widget.user!['phone'];
    }

    final result = await AuthService.verifyCode(phone: phone, code: code);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      _showSnackBar(result['message'] ?? "Verification successful!");

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showSnackBar(result['message'] ?? "Invalid code", isError: true);

      // Clear the code inputs on error
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004d71),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isNewUser ? 'Complete Registration' : 'Verify Login',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0xFF004d71), Color(0xFFF9F2E9)],
            stops: [0, 0.2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // User info card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isNewUser
                              ? 'Complete Your Registration'
                              : 'Enter Verification Code',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004d71),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '5-digit code was sent to ${widget.phoneOrEmail}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),

                        // Show user info if available
                        if (widget.user != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.user!['phone'] != null)
                                  Text(
                                    'Phone: ${widget.user!['phone']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (widget.user!['email'] != null)
                                  Text(
                                    'Email: ${widget.user!['email']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        // Verification code inputs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (index) => SizedBox(
                              width: 50,
                              height: 60,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                onChanged:
                                    (value) => _onCodeChanged(value, index),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Verify button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004d71),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _verifyCode,
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
                                    : Text(
                                      widget.isNewUser
                                          ? 'Complete Registration'
                                          : 'Verify & Login',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Resend code
                        Center(
                          child: TextButton(
                            onPressed:
                                _canResend && !_isLoading ? _resendCode : null,
                            child: Text(
                              _canResend
                                  ? 'Resend Code'
                                  : 'Resend Code ($_resendSeconds)',
                              style: TextStyle(
                                color:
                                    _canResend && !_isLoading
                                        ? const Color(0xFF004d71)
                                        : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
