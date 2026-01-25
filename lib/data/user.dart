class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final int rating;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.rating,
    this.photoURL,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'],
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      rating: data['rating'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'rating': rating,
    };
  }
}
