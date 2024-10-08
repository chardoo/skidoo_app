import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotographerTale extends StatelessWidget {
  PhotographerModel photographerModel = new PhotographerModel(
    '',
    '',
    '',
    '',
  );

  @override
  PhotographerTale({Key? key, required this.photographerModel})
      : super(key: key);
  Color mycolor = Color.fromARGB(255, 18, 21, 25);
  Color whitecolor = Color.fromARGB(255, 81, 77, 77);
  reduceDate(String text) {
    if (text.length > 10) {
      return text.substring(0, 16);
    } else {
      return text;
    }
  }

  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(bottom: 10),
        height: 60,
        width: 343,
        decoration: BoxDecoration(
            color: mycolor,
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
          ),
          title: Text(
            photographerModel.name!,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: whitecolor,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.normal,
                fontFamily: 'Open Sans',
                fontSize: 15),
          ),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reduceDate(photographerModel.contact.toString()),
                style: TextStyle(
                    color: whitecolor,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    fontFamily: 'Open Sans',
                    fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                photographerModel.email.toString(),
                style: TextStyle(
                    color: whitecolor,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    fontFamily: 'Open Sans',
                    fontSize: 15),
                overflow: TextOverflow.ellipsis,
              )
            ],
          ),
          onTap: () async {
            // controller.openDoc(document.documentURL);

            // Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //         builder: (context) => DocumentDetails(document)));
          },
        ));
  }
}
