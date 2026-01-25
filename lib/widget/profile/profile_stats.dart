import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rally_up/widget/common/common.dart';

import '../../provider/user.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;


    return PaddedCard(
      padding: 15,
      color: Colors.white54,
      child: Row(
        children: [
          Expanded(
            child: _profileAppStatsData(
              "Ratings",
              profile!.rating ?? 0,
            ),
          ),
          Expanded(
            child: FutureBuilder<int>(
              future: loadJoinedEventCount(profile.uid),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;

                return _profileAppStatsData(
                  "Matches",
                  count,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileAppStatsData(String title, int count) {
    return Column(
      children: [
        CenteredTitle(title, size: 18),
        SizedBox(
          height: 5.0,
        ),
        CenteredTitle("$count", size: 20),
      ],
    );
  }
}

Future<int> loadJoinedEventCount(String uid) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final snapshot = await firestore
      .collection('events')
      .where('participants', arrayContains: uid)
      .get();

  return snapshot.size;
}