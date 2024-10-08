import 'package:flutter/material.dart';
import 'package:skidoo_app/core/common/textfield.dart';


class PasswordField extends StatefulWidget {
   PasswordField({
    super.key,
    required TextEditingController pwdController,
    this.onSubmited,
    this.onChanged, required String? Function(dynamic value) validator, required this.label, this.placeholder,
  }) : _pwdController = pwdController;

  final TextEditingController _pwdController;
  final Function(String val)? onChanged;
 String? Function(String?)? onSubmited;
    final String label;
  final String? placeholder;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool isObscure = true;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   "Password",
        //   style: Theme.of(context)
        //       .textTheme
        //       .bodyLarge
        //       ?.copyWith(fontWeight: FontWeight.bold),
        // ),
        const SizedBox(height: 12),
        MyTextField(
          onSubmited: widget.onSubmited,
          keyboadType: TextInputType.visiblePassword, obscureText: isObscure,
          controller: widget._pwdController,
          onChanged: widget.onChanged,
          
          label: widget.label,
          // obsureText: isObscure,
          trailing: GestureDetector(
            onTap: () {
              setState(() {
                isObscure = !isObscure;
              });
            },
            child: Icon(
              isObscure ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
