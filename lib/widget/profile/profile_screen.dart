import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rally_up/provider/user.dart';
import 'package:rally_up/widget/common/common.dart';
import 'package:rally_up/widget/profile/profile_info.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileData = context.watch<ProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(),
      body: Container(
        decoration: BoxDecoration(
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              spacing: 20,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProfileInfo(userProfile: profileData!),
                // ProfileStats(),
                // Flexible(child: _MyReviewsButton()),
                Flexible(child: _LogOutButton()),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
            BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Events'),
          ],
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.redAccent.shade200,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          shadowColor: Colors.black38,
        ),
        icon: Icon(Icons.logout, size: 22),
        label: Text("Logout",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        onPressed: (){},
      ),
    );
  }
}