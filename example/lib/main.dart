
import 'package:example/grid_demo.dart';
import 'package:example/list_demo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        title: 'FlutterSectionListDemo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    var appBar = AppBar(
      title: Text('FlutterSectionListDemo'),
    );
    return Scaffold(
        appBar: appBar,
        body: ListView(
          children: List.generate(2, (index) => _getListItem(index, context)),
        ));
  }

  Widget _getListItem(int index, BuildContext context) {
    String title;
    switch (index) {
      case 0:
        title = 'SectionListView';
        break;
      case 1:
        title = 'SectionGridView';
        break;
    }

    return Stack(
      children: <Widget>[
        ListTile(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (BuildContext context) {
                  switch (index) {
                    case 0:
                      return SectionListDemo();

                    case 1:
                      return SectionGridViewDemo();
                  }

                  return null;
                }));
          },
          title: Text(title, style: TextStyle(fontSize: 16)),
        ),
        Positioned(
          child: Divider(height: 0.5),
          left: 0,
          right: 0,
          bottom: 0,
        )
      ],
    );
  }
}
