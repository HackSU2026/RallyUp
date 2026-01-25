import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';

class ImageWithDefault extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  const ImageWithDefault(
      {super.key,
        required this.photoUrl,
        required this.name,
        required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: photoUrl!=null ? Image(
        height: size,
        width: size,
        fit: BoxFit.fill,
        image: NetworkImage(photoUrl!),
      ):ProfilePicture(
        name: name,
        radius: size,
        fontsize: size,
      ),
    );
  }
}