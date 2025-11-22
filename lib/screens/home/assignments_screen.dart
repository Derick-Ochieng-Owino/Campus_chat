import 'package:flutter/material.dart';
import 'package:campus_app/core/constants/colors.dart';

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 80, color: AppColors.primary),
          SizedBox(height: 20),
          Text(
            "Assignments View",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Assignments uploaded by the Class Rep will be listed here. (Fetching from Firebase)",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.darkGrey),
            ),
          ),
        ],
      ),
    );
  }
}