import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myapp/app.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String uid;
  final String email;

  const VerifyEmailScreen({required this.uid, required this.email, super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verifyCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final code = _codeController.text.trim();

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(widget.uid)
              .collection("verification_codes")
              .doc(code)
              .get();

      final data = snapshot.data();
      final now = Timestamp.now();

      if (snapshot.exists &&
          data != null &&
          data['expiresAt'] != null &&
          (data['expiresAt'] as Timestamp).toDate().isAfter(now.toDate())) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(widget.uid)
            .update({"emailVerified": true});

        Navigator.pushReplacementNamed(context, AppRoutes.main);
      } else {
        setState(() {
          _error = "Invalid or expired code";
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred while verifying. Please try again.";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Enter the code sent to ${widget.email}"),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Verification Code"),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _verifyCode,
              child:
                  _loading
                      ? const CircularProgressIndicator()
                      : const Text("Verify"),
            ),
          ],
        ),
      ),
    );
  }
}
