import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  static const TextStyle title = TextStyle(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary);
  static const TextStyle subtitle = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.darkGrey);
  static const TextStyle chatTitle = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black);
  static const TextStyle chatMessage = TextStyle(
      fontSize: 14, color: Colors.black);
}