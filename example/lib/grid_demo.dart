
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_section_list/flutter_section_list.dart';

class SectionGridViewDemo extends StatefulWidget{

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _SectionGridViewState();
  }
}

class _SectionGridViewState extends State<SectionGridViewDemo> with SectionAdapterMixin, SectionGridAdapterMixin {

  final List<Color> colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple,];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("SectionGridView"),
      ),
      body: SectionGridView.builder(adapter: this),
    );
  }

  void _changeCount(){
    count = count == 20 ? 15 : 20;
  }

  int count = 15;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    // TODO: implement getItem

    EdgeInsets inset = getSectionInsets(indexPath.section);
    double totalWidth = crossAxisExtent - getCrossAxisSpacing(indexPath.section) - inset.left - inset.right;
    double width;
    double height;

    switch(indexPath.item % 6){
      case 0 :
      case 4 :
        width = totalWidth / 3;
        height = 200;
        break;
      default :
        width = totalWidth / 3 * 2;
        height = (200 - getMainAxisSpacing(indexPath.section)) / 2;
        break;
    }

    return GestureDetector(
      onTap: (){
        _changeCount();
      },
      child: Container(
        width: width,
        height: height,
        color: colors[Random().nextInt(colors.length - 1)],
        child: Center(
          child: Text('${indexPath.item}'),
        ),
      ),
    );
  }

  @override
  int numberOfItems(int section) {
    return this.count;
  }

  @override
  int numberOfSections() {
    return 10;
  }

  @override
  double getMainAxisSpacing(int section) {
    return 5;
  }

  @override
  double getCrossAxisSpacing(int section) {
    return 5;
  }

  @override
  EdgeInsets getSectionInsets(int section) {
    return EdgeInsets.fromLTRB(10, 8, 10, 8);
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
  double getFooterItemSpacing(int section) {
    return 5;
  }

  @override
  double getHeaderItemSpacing(int section) {
    return 5;
  }

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    return Container(
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
