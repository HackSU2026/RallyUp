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
        )
      ],
    );
  }
}

// class ProfileStats extends StatelessWidget {
//   const ProfileStats({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final profile = context.watch<ProfileProvider>();
//
//
//     return PaddedCard(
//       padding: 15,
//       color: Theme.of(context).colorScheme.onPrimary,
//       child: Row(
//         children: [
//           Expanded(
//             child: _profileAppStatsData(
//               "Reservations",
//               profile.getProfile.reservationsCount,
//             ),
//           ),
//           Expanded(
//             child: _profileAppStatsData(
//               "Reviews",
//               profile.getProfile.reviewsCount,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _profileAppStatsData(String title, int count) {
//     return Column(
//       children: [
//         CenteredTitle(title, size: 18),
//         SizedBox(
//           height: 5.0,
//         ),
//         CenteredTitle("$count", size: 20),
//       ],
//     );
//   }
// }