import 'package:flutter/material.dart';

import 'screen/home/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Link hive',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.lightGreenAccent)),
      home: const MyHomePage(),
    );
  }
}
