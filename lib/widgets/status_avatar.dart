import 'package:flutter/material.dart';

class StatusAvatar extends StatelessWidget {
  final String name;
  final bool viewed;
  final VoidCallback onTap;

  const StatusAvatar({
    required this.name,
    required this.viewed,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: viewed ? Colors.grey : Colors.green,
                width: 3,
              ),
            ),
            child: const CircleAvatar(radius: 25),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
