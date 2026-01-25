enum AuthStep {
  loggedOut,
  needsOnboarding,
  ready,
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final int rating;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.rating,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'],
      displayName: data['displayName'],
      rating: data['rating'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'rating': rating,
    };
  }
}
