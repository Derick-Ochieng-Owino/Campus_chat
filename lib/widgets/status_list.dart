import 'package:flutter/material.dart';
import '../services/status_service.dart';
import '../models/status_model.dart';
import 'status_avatar.dart';

class StatusList extends StatelessWidget {
  final StatusService service;

  const StatusList({required this.service, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StatusModel>>(
      stream: service.activeStatuses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 80);

        return SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final status = snapshot.data![i];
              return StatusAvatar(
                name: status.userName,
                viewed: false,
                onTap: () {
                  Navigator.pushNamed(context, '/status', arguments: status);
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: snapshot.data!.length,
          ),
        );
      },
    );
  }
}
