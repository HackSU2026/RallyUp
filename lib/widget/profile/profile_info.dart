import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rally_up/data/user.dart';
import 'package:rally_up/provider/user.dart';
import 'package:rally_up/widget/common/common.dart';


class ProfileInfo extends StatelessWidget {
  final UserProfile userProfile;
  const ProfileInfo({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ImageWithDefault(
            photoUrl: userProfile.photoURL, name: userProfile.displayName, size: 50,
        ),
        CenteredTitle(userProfile.displayName, size: 22),
        Text(
          userProfile.email,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
