// ignore_for_file: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
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
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(emailController.text.trim())) {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      _showSnackBar(
        'Registration successful! Please check your email to verify your account.',
      );
      // Navigate to login screen after successful registration
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showSnackBar('Sign Up Failed: $result');
    }
  }

  // Handle Google Sign-In
  void _handleGoogleSignIn() async {
    // For mobile platforms, use the legacy method
    if (!kIsWeb) {
      _signInWithGoogleLegacy();
      return;
    }

    // For web platforms, the sign-in is handled by the renderButton
    // This method should not be called directly on web
  }

  // Legacy Google Sign-In for mobile platforms
  void _signInWithGoogleLegacy() async {
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

  // Process Google Sign-In result
  void _processGoogleSignIn(GoogleSignInAccount? googleUser) async {
    if (googleUser == null) {
      _showSnackBar('Sign-In canceled');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? result = await _authService.processGoogleUser(googleUser);

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
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Sign Up"),
                    ),
                    const SizedBox(height: 10),
                    if (kIsWeb)
                      // Use renderButton for web platforms
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.g_mobiledata),
                          label: const Text("Sign Up with Google"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.grey),
                          ),
                          onPressed: () async {
                            try {
                              final GoogleSignIn _googleSignIn = GoogleSignIn(
                                clientId:
                                    '1042695203771-jtpf99vrp097uoeuj7o9q590uv3stfke.googleusercontent.com',
                                scopes: [
                                  'https://www.googleapis.com/auth/userinfo.profile',
                                  'https://www.googleapis.com/auth/userinfo.email',
                                ],
                              );
                              final isSignedIn =
                                  await _googleSignIn.isSignedIn();

                              GoogleSignInAccount? user;
                              if (isSignedIn) {
                                user =
                                    _googleSignIn.currentUser ??
                                    await _googleSignIn.signInSilently();
                              } else {
                                user = await _googleSignIn.signIn();
                              }

                              _processGoogleSignIn(user);
                            } catch (error) {
                              _showSnackBar('Error during sign in: $error');
                            }
                          },
                        ),
                      )
                    else
                      // Use custom button for mobile platforms
                      ElevatedButton.icon(
                        onPressed: _handleGoogleSignIn,
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
