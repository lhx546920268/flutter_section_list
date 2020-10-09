import 'package:flutter_section_list/src/section.dart';
import 'package:flutter/widgets.dart';

/// 列表分区适配器
abstract class SectionAdapter {

  ///列表交叉轴大小
  double crossAxisExtent;

  ///列表主轴大小
  double mainAxisExtent;

  ///数据变了
  bool notifyDataChange();

  ///构建item 组件，内部使用，通常情况下子类不需要重写这个
  Widget buildItem(BuildContext context, int position);

  ///item总数，内部使用，通常情况下子类不需要重写这个
  int getItemCount();

  ///通过position获取对应的sectionInfo
  SectionInfo sectionInfoForPosition(int position);

  ///获取对应section
  SectionInfo sectionInfoForSection(int section);

  ///创建sectionInfo
  SectionInfo createSection(int section, int numberOfItems, int position);
  SectionInfo createExtraSection(int section, int numberOfItems, int position);

  ///header 吸顶了
  void onSectionHeaderStick(int section);
}

mixin SectionAdapterMixin implements SectionAdapter {

  ///列表交叉轴大小
  @override
  double crossAxisExtent;

  ///列表主轴大小
  @override
  double mainAxisExtent;

  @override
  bool notifyDataChange(){
    _totalCount = null;
    _sectionInfos.clear();
    return true;
  }

  ///item总数
  int _totalCount;
  final List<SectionInfo> _sectionInfos = List();
  SectionInfo _headerSectionInfo;
  SectionInfo _footerSectionInfo;

  ///构建item 组件，内部使用，通常情况下子类不需要重写这个
  @override
  Widget buildItem(BuildContext context, int position) {

    if(shouldExistHeader() && position == 0){
      return getHeader(context);
    }else if(shouldExistFooter() && position == _totalCount - 1){
      return getFooter(context);
    }

    SectionInfo info = sectionInfoForPosition(position);
    if (info.isHeader(position)) {
      return getSectionHeader(context, info.section);
    } else if (info.isFooter(position)) {
      return getSectionFooter(context, info.section);
    } else {
      return getItem(
          context,
          IndexPath(
              section: info.section, item: info.getItemPosition(position)));
    }
  }

  ///item总数，内部使用，通常情况下子类不需要重写这个
  @override
  int getItemCount() {
    //计算列表行数量
    if(_totalCount == null){
      int numberOfSection = numberOfSections();
      int count = 0;

      if (shouldExistHeader()) {
        _headerSectionInfo = createExtraSection(-1, 0, count);
        count++;
      }

      for (int i = 0; i < numberOfSection; i++) {
        int numberOfItem = numberOfItems(i);

        ///保存section信息
        SectionInfo sectionInfo = createSection(i, numberOfItem, count);
        _sectionInfos.add(sectionInfo);
        count += numberOfItem;
        if (sectionInfo.isExistHeader) count++;
        if (sectionInfo.isExistFooter) count++;
      }

      if (shouldExistFooter()) {
        _footerSectionInfo = createExtraSection(_sectionInfos.length, 0, count);
        count++;
      }
      _totalCount = count;
    }

    return _totalCount;
  }

  ///创建sectionInfo
  @override
  SectionInfo createSection(int section, int numberOfItems, int position) {
    SectionInfo sectionInfo = SectionInfo(
        section: section,
        numberItems: numberOfItems,
        sectionBegin: position,
        isExistHeader: shouldExistSectionHeader(section),
        isExistFooter: shouldExistSectionFooter(section),
        isHeaderStick: shouldSectionHeaderStick(section));

    return sectionInfo;
  }

  @override
  SectionInfo createExtraSection(int section, int numberOfItems, int position) {
    return SectionInfo(section: section, numberItems: numberOfItems, sectionBegin: position);
  }

  ///通过position获取对应的sectionInfo
  @override
  SectionInfo sectionInfoForPosition(int position) {

    if(_totalCount == null) return null;

    if(position == 0 && shouldExistHeader()){
      return _headerSectionInfo;
    }

    if(position == _totalCount - 1 && shouldExistFooter()){
      return _footerSectionInfo;
    }

    if (_sectionInfos.length == 0) return null;

    var info = _sectionInfos[0];
    for (int i = 1; i < _sectionInfos.length; i++) {
      var sectionInfo = _sectionInfos[i];
      if (sectionInfo.sectionBegin > position) {
        break;
      } else {
        info = sectionInfo;
      }
    }
    return info;
  }

  ///获取对应section
  @override
  SectionInfo sectionInfoForSection(int section) {
    if (section >= 0 && section < _sectionInfos.length) {
      return _sectionInfos[section];
    }
    return null;
  }

  ///section总数
  int numberOfSections() {
    return 1;
  }

  ///每个section的item数量
  int numberOfItems(int section);

  ///获取item
  Widget getItem(BuildContext context, IndexPath indexPath);

  ///类似UITableView.tableHeaderView
  bool shouldExistHeader() {
    return false;
  }

  ///类似UITableView.tableFooterView
  bool shouldExistFooter() {
    return false;
  }

  ///section 头部
  bool shouldExistSectionHeader(int section) {
    return false;
  }

  ///section 底部
  bool shouldExistSectionFooter(int section) {
    return false;
  }

  ///是否需要吸顶悬浮
  bool shouldSectionHeaderStick(int section) {
    return false;
  }

  @override
  void onSectionHeaderStick(int section) {

  }

  Widget getHeader(BuildContext context) {
    throw UnimplementedError();
  }

  Widget getFooter(BuildContext context) {
    throw UnimplementedError();
  }

  Widget getSectionHeader(BuildContext context, int section) {
    throw UnimplementedError();
  }

  Widget getSectionFooter(BuildContext context, int section) {
    throw UnimplementedError();
  }
}

///section 网格适配器
abstract class SectionGridAdapter extends SectionAdapter {

  @override
  GridSectionInfo sectionInfoForPosition(int position);

  @override
  GridSectionInfo sectionInfoForSection(int section);
}

mixin SectionGridAdapterMixin on SectionAdapterMixin implements SectionGridAdapter {

  /// 滑动方向的 item间隔
  double getMainAxisSpacing(int section) {
    return 0;
  }

  /// 与滑动方向交叉 的item间隔
  double getCrossAxisSpacing(int section) {
    return 0;
  }

  ///section边距
  EdgeInsets getSectionInsets(int section) {
    return EdgeInsets.zero;
  }

  ///header和item的间距
  double getHeaderItemSpacing(int section) {
    return 0;
  }

  ///footer和item的间距
  double getFooterItemSpacing(int section) {
    return 0;
  }

  @override
  GridSectionInfo sectionInfoForPosition(int position){
    return super.sectionInfoForPosition(position);
  }

  @override
  GridSectionInfo sectionInfoForSection(int section){
    return super.sectionInfoForSection(section);
  }

  @override
  GridSectionInfo createSection(int section, int numberOfItems, int position) {
    GridSectionInfo sectionInfo = GridSectionInfo(
        section: section,
        numberItems: numberOfItems,
        sectionBegin: position,
        isExistHeader: shouldExistSectionHeader(section),
        isExistFooter: shouldExistSectionFooter(section),
        isHeaderStick: shouldSectionHeaderStick(section),
        mainAxisSpacing: getMainAxisSpacing(section),
        crossAxisSpacing: getCrossAxisSpacing(section),
        sectionInsets: getSectionInsets(section),
        headerItemSpacing: getHeaderItemSpacing(section),
        footerItemSpacing: getFooterItemSpacing(section));

    return sectionInfo;
  }

  @override
  GridSectionInfo createExtraSection(int section, int numberOfItems, int position) {
    return GridSectionInfo(section: section, numberItems: numberOfItems, sectionBegin: position);
  }
}
