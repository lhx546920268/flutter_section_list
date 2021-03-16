import 'package:flutter/cupertino.dart';

class IndexPath {
  final int section;
  final int item;

  IndexPath({required this.section, this.item = 0});

  @override
  String toString() {
    return 'section = $section, item = $item';
  }
}

class SectionInfo {
  ///section下标 section中行数 该section的起点 终点
  final int section;
  final int numberItems;
  final int sectionBegin;
  int get sectionEnd {
    int position = sectionBegin + numberItems - 1;
    if (isExistHeader) position++;
    if (isExistFooter) position++;
    return position;
  }

  ///是否存在 footer 和 header
  final bool isExistHeader;
  final bool isExistFooter;

  ///头部是否吸顶悬浮
  final bool isHeaderStick;

  ///头部布局信息
  dynamic headerGeometry;

  ///section 主轴最末端
  double mainEnd = 0;

  ///这个section是否是空的
  bool get isEmpty => !(isExistHeader || isExistFooter || numberItems > 0);

  SectionInfo(
      {required this.section,
      required this.numberItems,
      required this.sectionBegin,
      this.isExistHeader = false,
      this.isExistFooter = false,
      this.isHeaderStick = false});

  ///获取头部位置
  int getHeaderPosition() {
    return sectionBegin;
  }

  ///获取底部位置
  int getFooterPosition() {
    int footerPosition = sectionBegin;
    if (isExistHeader) footerPosition++;

    return footerPosition + numberItems;
  }

  ///获取item的起始位置
  int getItemStartPosition() {
    return isExistHeader ? sectionBegin + 1 : sectionBegin;
  }

  ///获取item在section的位置
  int getItemPosition(int position) {
    return position - getItemStartPosition();
  }

  ///判断position是否是头部
  bool isHeader(int position) {
    return isExistHeader && position == getHeaderPosition();
  }

  ///判断position是否是底部
  bool isFooter(int position) {
    return isExistFooter && position == getFooterPosition();
  }

  ///是否是item
  bool isItem(int position) {
    return !isHeader(position) && !isFooter(position);
  }

  ///是否包含某个下标
  bool include(int index) {
    return !isEmpty && index >= sectionBegin && index <= sectionEnd;
  }
}

class GridSectionInfo extends SectionInfo {
  /// 滑动方向的 item间隔
  double mainAxisSpacing;

  /// 与滑动方向交叉 的item间隔
  double crossAxisSpacing;

  ///section边距
  EdgeInsets sectionInsets;

  ///header和item的间距
  double headerItemSpacing;

  ///footer和item的间距
  double footerItemSpacing;

  GridSectionInfo(
      {required int section,
      required int numberItems,
      required int sectionBegin,
      bool isExistHeader = false,
      bool isExistFooter = false,
      bool isHeaderStick = false,
      this.mainAxisSpacing = 0,
      this.crossAxisSpacing = 0,
      this.sectionInsets = EdgeInsets.zero,
      this.headerItemSpacing = 0,
      this.footerItemSpacing = 0})
      : super(
            section: section,
            numberItems: numberItems,
            sectionBegin: sectionBegin,
            isExistFooter: isExistFooter,
            isExistHeader: isExistHeader,
            isHeaderStick: isHeaderStick);
}

