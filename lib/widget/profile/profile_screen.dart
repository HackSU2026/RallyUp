import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rally_up/provider/user.dart';
import 'package:rally_up/widget/common/common.dart';
import 'package:rally_up/widget/profile/profile_info.dart';
import 'package:rally_up/widget/profile/profile_stats.dart';

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
                ProfileStats(),
                Flexible(child: _UpcomingEventsButton()),
                Flexible(child: _HistoryButton()),
                Flexible(child: _LogOutButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventsButton extends StatelessWidget {
  const _UpcomingEventsButton();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    return _styledButton(
      text: "Upcoming Events",
      icon: Icons.reviews,
      bgColor: Colors.white,
      textColor: Colors.black,
      onPressed: () {
        // Navigator.of(context).push(
        //     MaterialPageRoute(builder: (ctx) => xxx(profile.id)));
      },
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    return _styledButton(
      text: "My History",
      icon: Icons.reviews,
      bgColor: Colors.white,
      textColor: Colors.black,
      onPressed: () {
        // Navigator.of(context).push(
        //     MaterialPageRoute(builder: (ctx) => xxx(profile.id)));
      },
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    return _styledButton(
      text: "Log Out",
      icon: Icons.logout,
      bgColor: Colors.redAccent.shade200,
      textColor: Colors.white,
      onPressed: () async {
        await profileProvider.signOut();
      },
    );
  }
}

Widget _styledButton({
  required String text,
  required IconData icon,
  required Color bgColor,
  required Color textColor,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        shadowColor: Colors.black38,
      ),
      icon: Icon(icon, size: 22),
      label: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      onPressed: onPressed,
    ),
  );
}