// examples/player/lib/src/ui/atoms/skeleton_box.dart
//
// O lugar de uma coisa que ainda vai aparecer.
import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double? height;
  final double? width;
  final double radius;

  const SkeletonBox({super.key, this.height, this.width, this.radius = 12});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
