import 'package:flutter/material.dart';
import 'package:campus_app/core/constants/colors.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign, size: 80, color: AppColors.accent),
          SizedBox(height: 20),
          Text(
            "Announcements",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Important notices from the department or school will appear here. (Fetching from Firebase)",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.darkGrey),
            ),
          ),
        ],
      ),
    );
  }
}