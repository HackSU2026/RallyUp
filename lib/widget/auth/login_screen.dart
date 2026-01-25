import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _dialogShown = false;

  void _showLevelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final profile = context.read<ProfileProvider>();

        return AlertDialog(
          title: const Text('Select your skill level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  profile.completeOnboarding(
                    selectedLevel: 'beginner',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Beginner'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  profile.completeOnboarding(
                    selectedLevel: 'intermediate',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Intermediate'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  profile.completeOnboarding(
                    selectedLevel: 'advanced',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Advanced'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    if (profile.step == AuthStep.needsOnboarding && !_dialogShown) {
      _dialogShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLevelDialog(context);
      });
    }

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Image(
                image: AssetImage("assets/logo.png"),
                width: 300,
                height: 300,
                alignment: Alignment.bottomCenter,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                "Rally Up",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 3,
              child: _MicrosoftSignInButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicrosoftSignInButton extends StatelessWidget {
  const _MicrosoftSignInButton();

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();

    return Column(
      children: [
      ElevatedButton.icon(
          onPressed: profileProvider.isLoading
              ? null
              :() async {
            await profileProvider.signInWithMicrosoft();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          icon: Image.asset(
        'assets/microsoft.png',
              height: 30,
          ),
          label: Text("Sign in with Microsoft"),
        ),
      ],
    );
  }
}