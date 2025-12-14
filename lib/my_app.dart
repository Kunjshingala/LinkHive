import 'package:flutter/material.dart';
import 'package:link_hive/utils/navigation/route.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Link hive',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreenAccent)),
      routerConfig: router,
    );
  }
}
