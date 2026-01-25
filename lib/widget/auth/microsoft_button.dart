import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Styled Microsoft Sign-In button with loading state and animations.
class MicrosoftSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const MicrosoftSignInButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<MicrosoftSignInButton> createState() => _MicrosoftSignInButtonState();
}

class _MicrosoftSignInButtonState extends State<MicrosoftSignInButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign in with your Microsoft account',
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIcon(),
                    const SizedBox(width: 14),
                    _buildText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 900.ms)
        .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 900.ms, curve: Curves.easeOut);
  }

  Widget _buildIcon() {
    if (widget.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F1F1F)),
        ),
      );
    }

    return Image.asset(
      'assets/microsoft.png',
      height: 24,
      width: 24,
    );
  }

  Widget _buildText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        widget.isLoading ? 'Signing in...' : 'Continue with Microsoft',
        key: ValueKey(widget.isLoading),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F1F1F),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
