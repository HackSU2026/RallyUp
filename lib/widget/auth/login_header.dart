import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated header widget containing the app logo, name, and tagline.
/// Uses staggered animations for a polished entry effect.
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing
    final logoSize = screenWidth >= 768 ? 180.0 : (screenWidth >= 428 ? 150.0 : 120.0);
    final titleSize = screenWidth >= 768 ? 48.0 : (screenWidth >= 428 ? 40.0 : 36.0);
    final taglineSize = screenWidth >= 768 ? 20.0 : 18.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo with glow effect
        _buildLogo(logoSize),

        SizedBox(height: logoSize * 0.2),

        // App name
        _buildAppName(titleSize),

        const SizedBox(height: 12),

        // Tagline
        _buildTagline(taglineSize),
      ],
    );
  }

  Widget _buildLogo(double size) {
    return Semantics(
      label: 'Rally Up logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 15,
            ),
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 60,
              spreadRadius: 20,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: -0.3, end: 0, duration: 600.ms, delay: 200.ms, curve: Curves.easeOutBack)
        .then()
        .shimmer(duration: 2000.ms, delay: 500.ms);
  }

  Widget _buildAppName(double fontSize) {
    return Text(
      'RALLY UP',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 4.0,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 500.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 500.ms, delay: 500.ms);
  }

  Widget _buildTagline(double fontSize) {
    return Text(
      'Find your next rally',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.75),
        letterSpacing: 0.5,
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 700.ms);
  }
}
