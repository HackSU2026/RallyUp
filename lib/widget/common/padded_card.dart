import 'package:flutter/material.dart';

class PaddedCard extends StatelessWidget {
  final double padding;
  final Color? color;
  final Widget? child;

  const PaddedCard({super.key, this.child, this.padding = 10, this.color});

  @override
  Widget build(BuildContext context) {
    Color bg = Theme.of(context).colorScheme.primaryContainer;
    if (color != null) {
      bg = color!;
    }
    return Card(
      color: bg,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}