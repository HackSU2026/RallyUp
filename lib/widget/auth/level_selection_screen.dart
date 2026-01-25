import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/user.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.read<ProfileProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Center(child:Text("Select your skill level"),),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          ElevatedButton(
            onPressed: () {
              profile.completeOnboarding(
                selectedLevel: 'beginner',
              );
            },
            child: const Text('Beginner'),
          ),
          ElevatedButton(
            onPressed: () {
              profile.completeOnboarding(
              selectedLevel: 'intermediate',
              );
            },
            child: const Text('Intermediate'),
          ),
          ElevatedButton(
            onPressed: () {
              profile.completeOnboarding(
              selectedLevel: 'advanced',
              );
            },
            child: const Text('Advanced'),
          ),
        ],
      ),
    ),
    );
  }
}
