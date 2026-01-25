import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Footer widget displaying terms and privacy policy links.
class TermsFooter extends StatelessWidget {
  const TermsFooter({super.key});

  // Update these URLs with your actual terms and privacy policy pages
  static const String _termsUrl = 'https://rallyup.app/terms';
  static const String _privacyUrl = 'https://rallyup.app/privacy';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      fontSize: 12,
      color: Colors.white.withOpacity(0.7),
      decoration: TextDecoration.underline,
      decorationColor: Colors.white.withOpacity(0.5),
    );

    final normalStyle = TextStyle(
      fontSize: 12,
      color: Colors.white.withOpacity(0.5),
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: normalStyle,
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(_termsUrl),
          ),
          const TextSpan(text: '\nand '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(_privacyUrl),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 1100.ms);
  }
}
