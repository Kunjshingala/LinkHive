import 'package:flutter/material.dart';
import 'package:link_hive/screen/home/home_bloc.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  HomeBloc? _bloc;

  @override
  void didChangeDependencies() {
    _bloc ??= HomeBloc();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _bloc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Link hive"),
        actions: [
          GestureDetector(
            onTap: () {},
            child: Icon(Icons.account_circle_rounded, color: Colors.black, size: 30),
          ),
          SizedBox(width: 15),
        ],
      ),
      body: Center(child: Column()),
    );
  }
}
