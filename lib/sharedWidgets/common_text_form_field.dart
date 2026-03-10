import 'package:flutter/material.dart';

class CommonTextFormField extends StatelessWidget {
  final TextEditingController? textEditingController;

  const CommonTextFormField({super.key, this.textEditingController});

  @override
  Widget build(BuildContext context) {
    return TextFormField(controller: textEditingController);
  }
}
