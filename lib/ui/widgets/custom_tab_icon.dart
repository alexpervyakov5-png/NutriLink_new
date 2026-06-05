import 'package:flutter/material.dart';
import '../../core/config.dart';

/// Виджет для иконок вкладок с поддержкой активного/неактивного состояния
class CustomTabIcon extends StatelessWidget {
  final String iconPath;
  final String activeIconPath;
  final bool isActive;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const CustomTabIcon({
    super.key,
    required this.iconPath,
    required this.activeIconPath,
    required this.isActive,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      isActive ? activeIconPath : iconPath,
      width: size,
      height: size,
      color: isActive 
          ? (activeColor ?? AppColors.accentLight) 
          : (inactiveColor ?? Colors.grey),
      errorBuilder: (_, __, ___) => Icon(
        Icons.circle,
        size: size,
        color: isActive ? AppColors.accentLight : Colors.grey,
      ),
    );
  }
}

/// Простой виджет для отображения кастомной иконки
class CustomIcon extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final Color? color;
  final Widget? fallback;

  const CustomIcon({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.color,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: width,
      height: height,
      color: color,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}