import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:intl/intl.dart';
import 'package:skidoo_app/controller/home_controller.dart';
import 'package:skidoo_app/models/event/Event.dart';

class SearchTale extends StatelessWidget {
  // ignore: empty_constructor_bodies
  HomeController controller = Get.find();
  Event event = new Event('', '', '','');

  @override
  SearchTale({Key? key, required this.event}) : super(key: key);
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(right: 0, left: 0),
         height: 55,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 227, 225, 225),
           borderRadius: BorderRadius.all(Radius.circular(20))
        ),
        child: ListTile(
         
          leading: Text(event.photographer,
              style: const TextStyle(
                  color: Color.fromARGB(255, 33, 32, 32),
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.normal,
                  fontFamily: 'Open Sans',
                  fontSize: 15)),
          title: Text(
            event.eventName,
            overflow: TextOverflow.ellipsis,
             style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold,color: Colors.black),
          ),
          subtitle: Text(
            DateFormat.yMMMd()
                .format(DateTime.parse(event.eventDate))
                .toString(),
            overflow: TextOverflow.ellipsis,
             style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.normal, fontSize: 14, color: Colors.black),
          ),
          onTap: () async {
            Get.toNamed('/searchresults');
            await controller.searchimages(event.id);
            Timer(const Duration(seconds: 10), () async {
              if (controller.searchImage.isEmpty) {
                await controller.searchimages(event.eventName);
              } else {}
            });
            Timer(const Duration(seconds: 20), () async {
              if (controller.searchImage.isEmpty) {
                await controller.searchimages(event.eventName);
              } else {}
            });
          },
        ));
  }
}
