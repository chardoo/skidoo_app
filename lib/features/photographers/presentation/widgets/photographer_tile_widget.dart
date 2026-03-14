import 'package:flutter/material.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotographerTileWidget extends StatelessWidget {
  final PhotographerModel photographer;
  const PhotographerTileWidget({super.key, required this.photographer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 50, 50, 50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color.fromARGB(255, 80, 80, 80),
            child: Text(
              photographer.name.isNotEmpty
                  ? photographer.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photographer.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  photographer.email,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 180, 178, 178),
                    fontSize: 12,
                  ),
                ),
                if (photographer.contact.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    photographer.contact,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 150, 148, 148),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
