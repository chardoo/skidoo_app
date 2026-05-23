
import 'package:flutter/material.dart';
import 'package:skidoo_app/core/common/customButtom.dart';

class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return  CustomButtonTwo(label: const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),),
                      ontap: (){},);
  }
}