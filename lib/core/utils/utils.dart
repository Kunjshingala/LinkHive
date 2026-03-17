import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../my_app.dart';

void showSnackBar(String message) {
  scaffoldMessengerKey.currentState?.clearSnackBars();

  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Container(color: AppColors.black, child: Text(message)),
    ),
  );
}

void printLog({String tag = "Utils", required String msg}) {
  debugPrint("$tag ----------> $msg");
}
