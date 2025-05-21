import 'package:flutter/material.dart';
import 'package:myapp/services/auth_services.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Validate inputs before registration
  bool _validateInputs() {
    if (usernameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a username');
      return false;
    }
    if (emailController.text.trim().isEmpty || !emailController.text.contains('@')) {
      _showSnackBar('Please enter a valid email');
      return false;
    }
    if (passwordController.text.trim().length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return false;
    }
    return true;
  }

  // Show SnackBar for user feedback
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Register user with email and password
  void _registerUser() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    String? result = await _authService.registerWithEmail(
      emailController.text.trim(),
      passwordController.text.trim(),
      usernameController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (result == null) {
      _showSnackBar('Registration successful! Please check your email to verify your account.');
      // Navigate to login screen after successful registration
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showSnackBar('Sign Up Failed: $result');
    }
  }

  // Sign in with Google
  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    String? result = await _authService.signInWithGoogle();

    setState(() {
      _isLoading = false;
    });

    if (result == null) {
      // Navigate to main screen after successful Google Sign-In
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      _showSnackBar('Google Sign-In Failed: $result');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text("Sign Up"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text("Sign Up with Google"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text("Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}