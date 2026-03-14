import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skidoo_app/models/event/Event.dart';

class SearchItemWidget extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const SearchItemWidget({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String formattedDate = '';
    try {
      formattedDate = DateFormat.yMMMd()
          .format(DateTime.parse(event.eventDate))
          .toString();
    } catch (_) {
      formattedDate = event.eventDate;
    }

    return Container(
      margin: const EdgeInsets.only(right: 0, left: 0),
      height: 55,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 227, 225, 225),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: ListTile(
        leading: Text(
          event.photographer,
          style: const TextStyle(
            color: Color.fromARGB(255, 33, 32, 32),
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.normal,
            fontSize: 15,
          ),
        ),
        title: Text(
          event.eventName,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        subtitle: Text(
          formattedDate,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                  color: Colors.black),
        ),
        onTap: onTap,
      ),
    );
  }
}
