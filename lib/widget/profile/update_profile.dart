import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/user.dart';

class UpdateProfile extends StatefulWidget {
  const UpdateProfile({Key? key}) : super(key: key);

  @override
  State<UpdateProfile> createState() => _UpdateProfileState();
}

class _UpdateProfileState extends State<UpdateProfile> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();

    // 👇 Prefill with existing name
    final profile =
        context.read<ProfileProvider>().profile;

    _nameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Display Name",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your name",
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                await provider.updateProfile(
                  updates: {
                    'displayName':
                    _nameController.text.trim(),
                  },
                );

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: provider.isLoading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
