import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/user.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                "Match Point",
                style: TextStyle(fontSize: 30),
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
        ElevatedButton(
          onPressed: () async {
            profileProvider.signInWithMicrosoft();
          },
          child: Text("HEHE"),

        ),
      ],
    );
  }
}