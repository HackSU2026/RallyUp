import 'package:flutter/material.dart';

/// Background widget for the login screen using a custom image.
class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/loginbg.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
