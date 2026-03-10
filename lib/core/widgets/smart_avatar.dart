import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SmartAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const SmartAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    // si tiene url descarga y guarda em cache
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[800],
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    final String initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.red[900],
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}
