import 'package:flutter/material.dart';
import 'package:city_path/screens/home_screen.dart';
import 'package:city_path/services/auth_service.dart';
import 'package:city_path/screens/verify_code_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLogin = true; // true = login, false = register
  bool _isLoading = false;

  // Toggle between login and register
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      // Clear controllers when switching modes
      _phoneController.clear();
      _emailController.clear();
    });
  }

  // Handle login
  Future<void> _handleLogin() async {
    final phoneOrEmail = _phoneController.text.trim();

    if (phoneOrEmail.isEmpty) {
      _showSnackBar("Please enter phone or email");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.loginUser(phoneOrEmail: phoneOrEmail);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      _showSnackBar(result['message']);
      _navigateToVerification(phoneOrEmail, result['user']);
    } else {
      if (result['error'] == 'user_not_found') {
        _showSnackBar(
          result['message'] + "\n\nTap 'Register' to create a new account.",
          isError: true,
        );
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    }
  }

  // Handle registration
  Future<void> _handleRegister() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (phone.isEmpty || email.isEmpty) {
      _showSnackBar("Please enter both phone and email");
      return;
    }

    if (!_isValidEmail(email)) {
      _showSnackBar("Please enter a valid email address");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.registerUser(phone: phone, email: email);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      _showSnackBar(result['message']);
      _navigateToVerification(phone, result['user']);
    } else {
      if (result['error'] == 'user_exists') {
        _showSnackBar(
          result['message'] + "\n\nTap 'Login' to sign in to your account.",
          isError: true,
        );
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    }
  }

  void _navigateToVerification(String phone, Map<String, dynamic>? user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => VerifyCodeScreen(
              phoneOrEmail: phone,
              isNewUser: !_isLogin,
              user: user,
            ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Logo
                Image.asset('assets/logo.png', width: 160),
                const SizedBox(height: 40),

                // Title
                Text(
                  _isLogin ? 'Welcome' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004d71),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in to your account'
                      : 'Sign up to get started',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                // Phone field
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _isLogin ? 'Phone or Email' : 'Phone Number',
                    hintText:
                        _isLogin
                            ? 'Enter phone or email'
                            : 'Enter phone number',
                    prefixIcon: Icon(_isLogin ? Icons.person : Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                // Email field (only for registration)
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'Enter email address',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Submit button
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
                    onPressed:
                        _isLoading
                            ? null
                            : (_isLogin ? _handleLogin : _handleRegister),
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
                              _isLogin ? 'Login' : 'Register',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 24),

                // Switch between login/register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? "Don't have an account? "
                          : "Already have an account? ",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    TextButton(
                      onPressed: _toggleMode,
                      child: Text(
                        _isLogin ? 'Register' : 'Login',
                        style: const TextStyle(
                          color: Color(0xFF004d71),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
