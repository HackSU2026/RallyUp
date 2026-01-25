import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/user.dart';
import 'login_background.dart';
import 'login_header.dart';
import 'microsoft_button.dart';
import 'skill_level_sheet.dart';
import 'terms_footer.dart';

/// Modern, redesigned login screen with custom background image,
/// animated elements, and smooth Microsoft OAuth flow.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _sheetShown = false;

  void _showSkillLevelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SkillLevelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;

    // Show skill level sheet when onboarding is needed
    if (profile.step == AuthStep.needsOnboarding && !_sheetShown) {
      _sheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSkillLevelSheet(context);
      });
    }

    // Reset sheet shown flag when logged out
    if (profile.step == AuthStep.loggedOut && _sheetShown) {
      _sheetShown = false;
    }

    // Responsive padding
    final horizontalPadding = isTablet ? 80.0 : 32.0;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background image - covers full screen
            const Positioned.fill(
              child: LoginBackground(),
            ),

            // Main content - centered
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Logo, app name, and tagline
                      const LoginHeader(),

                      const Spacer(flex: 2),

                      // Microsoft Sign-in Button
                      MicrosoftSignInButton(
                        isLoading: profile.isLoading,
                        onPressed: () async {
                          await profile.signInWithMicrosoft();
                        },
                      ),

                      const Spacer(flex: 1),

                      // Terms and Privacy Policy
                      const TermsFooter(),

                      SizedBox(height: isTablet ? 40 : 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
