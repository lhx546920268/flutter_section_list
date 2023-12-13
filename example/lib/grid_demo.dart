
import 'package:easy_refresh/easy_refresh.dart';
import 'package:example/list_demo.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_section_list/flutter_section_grid.dart';

class SectionGridViewDemo extends StatefulWidget{

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _SectionGridViewState();
  }
}

class _SectionGridViewState extends State<SectionGridViewDemo> with SectionAdapterMixin, SectionGridAdapterMixin {

  final List<Color> colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple,];
  late List<Section> sections;
  final EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishLoad: true
  );

  @override
  void initState() {
    sections = buildSections();
    super.initState();
  }

  List<Section> buildSections() {
    final data = <Section>[];
    for(int i = 0;i < 5;i ++) {
      data.add(buildSection(i));
    }

    return data;
  }

  Section buildSection(int section) {
    final length = colors.length - 1;
    final random = Random();
    final items = <Item>[];
    for(int j = 0;j < 9;j ++) {
      items.add(Item("Section = $section, Item = $j", colors[random.nextInt
        (length)]));
    }
    return Section("Section Header $section", colors[random.nextInt
      (length)], items);
  }

  addItems(Section section) {
    final length = colors.length - 1;
    final random = Random();
    final items = section.items;
    for(int j = 0;j < 18;j ++) {
      items.add(Item("Section = $section, Item = ${items.length}", colors[random
          .nextInt(length)]));
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("SectionGridView"),
      ),
      body: EasyRefresh(
        controller: easyRefreshController,
        child: SectionGridView.builder(adapter: this),
        onLoad: _onLoadMore,
      ),
    );
  }

  void _onLoadMore() async {
    await Future.delayed(Duration(seconds: 2), _changeCount);
  }

  void _changeCount() {
    setState(() {
//      invalidateCache();
    addItems(sections.last);
    easyRefreshController.finishLoad(IndicatorResult.noMore);
//     sections.add(buildSection(sections.length));
    });
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {

    EdgeInsets inset = getSectionInsets(indexPath.section);
    double totalWidth = crossAxisExtent - inset.left - inset.right;
    double width;
    double height;

    switch(indexPath.item % 6){
      case 0 :
      case 4 :
        width = totalWidth / 3;
        height = 200;
        break;
      default :
        width = totalWidth / 3 * 2 - getCrossAxisSpacing(indexPath.section);
        height = (200 - getMainAxisSpacing(indexPath.section)) / 2;
        break;
    }

    final item = sections[indexPath.section].items[indexPath.item];
    return Container(
      width: width,
      height: height,
      color: item.color,
      child: Center(
        child: Text(item.title),
      ),
    );
  }

  @override
  int numberOfItems(int section) {
    return sections[section].items.length;
  }

  @override
  int numberOfSections() {
    return sections.length;
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
        child: Text(sections[section].title),
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
  Widget getHeader(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.amber,
      child: Center(
        child: Text('Header'),
      ),
    );
  }
}
