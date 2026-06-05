import 'package:flutter/material.dart';
import '../../core/config.dart';

class CustomTabIcon extends StatelessWidget {
  final String iconPath;
  final String activeIconPath;
  final bool isActive;
  final double size;

  const CustomTabIcon({
    super.key,
    required this.iconPath,
    required this.activeIconPath,
    required this.isActive,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      isActive ? activeIconPath : iconPath,
      width: size,
      height: size,
      color: isActive ? AppColors.accentLight : Colors.grey,
    );
  }
}

class CustomIcon extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final Color? color;

  const CustomIcon({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: width,
      height: height,
      color: color,
    );
  }
}