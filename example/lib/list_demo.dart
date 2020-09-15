
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

class SectionListDemo extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return _SectionListDemoState();
  }
}

class _SectionListDemoState extends State<SectionListDemo> with SectionAdapterMixin{

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SectionListDemo'),),
      body: SectionListView.builder(adapter: this),
    );
  }

  @override
  int numberOfSections() {
    return 10;
  }

  @override
  int numberOfItems(int section) {
    return 15;
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: <Widget>[
        ListTile(
          title: Text('$indexPath'),
        ),
        Divider(height: 0.5,)
      ],
    );
  }

  @override
  bool shouldExistSectionHeader(int section) {
    return true;
  }

  @override
  bool shouldSectionHeaderStick(int section) {
    return true;
  }

  @override
  bool shouldExistSectionFooter(int section) {
    return section % 2 != 0;
  }

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    return Container(
      key: GlobalKey(debugLabel: 'header $section'),
      height: 45,
      color: Colors.blue,
      child: Center(
        child: Text('Header $section'),
      ),
    );
  }

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    return Container(
      key: GlobalKey(debugLabel: 'footer $section'),
      height: 45,
      color: Colors.green,
      child: Center(
        child: Text('Footer $section'),
      ),
    );
  }

  @override
  bool shouldExistHeader() {
    return true;
  }

  @override
  bool shouldExistFooter() {
    return true;
  }

  @override
  Widget getHeader(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.amber,
      child: Center(
        child: Text('Header'),
      ),
    );
  }

  @override
  Widget getFooter(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.amber,
      child: Center(
        child: Text('Footer'),
      ),
    );
  }
}

