
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

class SectionListDemo extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return _SectionListDemoState();
  }
}

class _SectionListDemoState extends State<SectionListDemo> with SectionAdapterMixin{

  final List<Color> colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple,];
  late List<Section> sections;

  List<Section> buildSections() {
    final random = Random();
    final length = colors.length - 1;
    final data = <Section>[];
    for(int i = 0;i < 100;i ++) {
      final items = <Item>[];
      for(int j = 0;j < 100;j ++) {
        items.add(Item("Section = $i, Item = $j", colors[random.nextInt
          (length)]));
      }
      data.add(Section("Section Header $i", colors[random.nextInt
        (length)], items));
    }
    
    return data;
  }

  @override
  void initState() {
    sections = buildSections();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('SectionListDemo'),),
        body: SectionListView.builder(adapter: this));
  }

  @override
  int numberOfSections() {
    return sections.length;
  }

  @override
  int numberOfItems(int section) {
    return sections[section].items.length;
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    final item = sections[indexPath.section].items[indexPath.item];
    return GestureDetector(key: ObjectKey(item), onTap: () {
      setState(() {
        final section = sections[indexPath.section];
        section.items.removeAt(indexPath.item);
        if (section.items.isEmpty) {
          sections.removeAt(indexPath.section);
        }
      });
    }, child: Container(
      color: item.color,
      child: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: <Widget>[
          ListTile(
            title: Text(item.title),
          ),
          Divider(height: 0.5,)
        ],
      ),
    ),);
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
    final data = sections[section];

    return Container(
      key: ObjectKey(data.title),
      height: 45,
      color: data.color,
      child: Center(
        child: Text(data.title),
      ),
    );
  }

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    final data = sections[section];
    return Container(
      key: ObjectKey(data),
      height: 45,
      color: data.color,
      child: Center(
        child: Text('Footer $section'),
      ),
    );
  }

  var existHeader = true;

  @override
  bool shouldExistHeader() {
    return existHeader;
  }

  @override
  bool shouldExistFooter() {
    return true;
  }

  @override
  Widget getHeader(BuildContext context) {
    return GestureDetector(onTap: () {
      setState(() {
        existHeader = false;
      });
    }, child: Container(
      height: 200,
      color: Colors.amber,
      child: Center(
        child: Text('Header'),
      ),
    ),);
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

class Section {
  String title;
  Color color;
  List<Item> items;

  Section(this.title, this.color, this.items);
}

class Item {
  String title;
  Color color;

  Item(this.title, this.color);
}