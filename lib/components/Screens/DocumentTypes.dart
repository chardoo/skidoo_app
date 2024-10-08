
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';


class DocumentTypesNavigationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Document Types",
          style: TextStyle(
              color: Colors.black, fontSize: 26, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Color.fromARGB(255, 230, 233, 239),
      ),
      floatingActionButton: new FloatingActionButton(
        backgroundColor: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              color: Color.fromARGB(255, 245, 243, 243),
            )
          ],
        ),
        onPressed: () {},
      ),
      body: body(),
    );
  }

  Widget body() {
    return SafeArea(
        child: Scaffold(
            backgroundColor: Color.fromARGB(255, 230, 233, 239),
            body: Column(children: [
              // Expanded(
              //   child: Container(
              //     margin: EdgeInsets.only(left: 16, right: 16),
              //     child: SizedBox(
              //       child: new ListView.builder(
              //         scrollDirection: Axis.vertical,
              //         itemCount: 3,
              //         itemBuilder: (BuildContext ctxt, int index) {
              //           return new DocumentTale();
              //         },
              //       ),
              //     ),
              //   ),
              // )
            ])));
  }
}
