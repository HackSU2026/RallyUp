import 'package:flutter/material.dart';

class CenteredTitle extends StatelessWidget {
  final String text;
  final double size;
  final double horizontal;
  final double vertical;
  const CenteredTitle(this.text,
      {super.key, this.size = 14, this.horizontal = 0, this.vertical = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: size),
        ),
      ),
    );
  }
}