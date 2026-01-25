import 'package:flutter/material.dart';

/// Gradient background widget for the login screen.
/// Creates a deep purple gradient with a subtle radial glow effect.
class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  // Color palette for the gradient
  static const Color gradientStart = Color(0xFF1A0033);   // Dark purple-black
  static const Color gradientMiddle = Color(0xFF4A148C); // Deep purple
  static const Color gradientLight = Color(0xFF6A1B9A);  // Purple
  static const Color gradientEnd = Color(0xFF7C4DFF);    // Light purple accent

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientStart,
            gradientMiddle,
            gradientLight,
            gradientEnd,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Radial glow behind logo area
          Positioned(
            top: MediaQuery.of(context).size.height * 0.12,
            left: 0,
            right: 0,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.4),
                    Colors.purple.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Bottom ambient glow
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.deepPurple.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
