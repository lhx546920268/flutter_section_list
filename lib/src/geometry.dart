import 'dart:collection';

import 'package:flutter_section_list/src/section.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;

///列表布局信息
class ItemGeometry{

  double scrollOffset;
  double mainAxisExtent;

  ItemGeometry({
    required this.scrollOffset,
    required this.mainAxisExtent,
  });

  ItemGeometry copyWith({
    double? scrollOffset,
    double? mainAxisExtent,
  }) {
    return ItemGeometry(
        scrollOffset: scrollOffset ?? this.scrollOffset,
        mainAxisExtent: mainAxisExtent ?? this.mainAxisExtent,
    );
  }

  double get mainEnd => scrollOffset + mainAxisExtent;
}

///item布局信息
class ItemGridGeometry extends ItemGeometry{

  double crossAxisOffset;
  double crossAxisExtent;

  ItemGridGeometry({
    double scrollOffset = 0,
    this.crossAxisOffset = 0,
    double mainAxisExtent = 0,
    this.crossAxisExtent = 0,
  }) : super(
    scrollOffset : scrollOffset,
    mainAxisExtent: mainAxisExtent
  );

  ItemGridGeometry copyWith({
    double? scrollOffset,
    double? crossAxisOffset,
    double? mainAxisExtent,
    double? crossAxisExtent,
  }) {
    return ItemGridGeometry(
        scrollOffset: scrollOffset ?? this.scrollOffset,
        crossAxisOffset: crossAxisOffset ?? this.crossAxisOffset,
        mainAxisExtent: mainAxisExtent ?? this.mainAxisExtent,
        crossAxisExtent: crossAxisExtent ?? this.crossAxisExtent
    );
  }

  double get crossEnd => crossAxisOffset + crossAxisExtent;
}


///布局行信息
class RowGridGeometry{

  ///当前交叉轴的偏移量
  double crossAxisOffset = 0;

  ///当前主轴的偏移量
  double scrollOffset;

  ///当前主轴上的最末端 item
  ItemGridGeometry? endGeometry;
  double get mainEnd => endGeometry != null ? endGeometry!.mainEnd : scrollOffset;

  ///主轴上的外部item信息
  List<ItemGridGeometry> outermostItemGeometries = [];

  RowGridGeometry({required this.scrollOffset});

  RowGridGeometry copyWith({
    double? scrollOffset,
  }) {


    RowGridGeometry rowGridGeometry = RowGridGeometry(
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
    rowGridGeometry.crossAxisOffset = crossAxisOffset;
    rowGridGeometry.endGeometry = endGeometry?.copyWith();
    for(ItemGridGeometry geometry in outermostItemGeometries){
      rowGridGeometry.outermostItemGeometries.add(geometry.copyWith());
    }
    return rowGridGeometry;
  }

  ///新一行
  void newLine(GridSectionInfo previousSectionInfo, GridSectionInfo sectionInfo, int index){
    crossAxisOffset = 0;
    scrollOffset = endGeometry?.mainEnd ?? 0;
    if(sectionInfo.sectionBegin == index){
      if(sectionInfo.section != 0){
        scrollOffset += previousSectionInfo.sectionInsets.bottom;
      }
      scrollOffset += sectionInfo.sectionInsets.top;

    }else{
      if(sectionInfo.isHeader(index - 1)){
        scrollOffset += sectionInfo.headerItemSpacing;
      }else if(sectionInfo.isFooter(index + 1)){
        scrollOffset += sectionInfo.footerItemSpacing;
      }else{
        scrollOffset += sectionInfo.mainAxisSpacing;
      }
    }
    outermostItemGeometries.clear();
  }

  ///更新尾部
  void updateEndGeometry(ItemGridGeometry geometry){
    if(endGeometry == null){
      endGeometry = geometry;
    }else if(geometry.mainEnd > endGeometry!.mainEnd){
      endGeometry = geometry;
    }
  }

  ///遍历最外围的item，获取最低的并且适合itemGridGeometry大小的item
  int traverseOutermostItemGeometries(ItemGridGeometry itemGridGeometry){
    int index = -1;
    if(outermostItemGeometries.length > 0){
      index = 0;
      ItemGridGeometry geometry = outermostItemGeometries[0];
      for(int i = 1;i < outermostItemGeometries.length;i ++){
        ItemGridGeometry tmp = outermostItemGeometries[i];
        //最低，并且可以放下item
        if(tmp.mainEnd <= geometry.mainEnd && tmp.crossAxisExtent >= itemGridGeometry.crossAxisExtent){
          if(tmp.mainEnd == geometry.mainEnd){
            //拿最左边的
            if(tmp.crossAxisOffset < geometry.crossAxisOffset){
              geometry = tmp;
              index = i;
            }
          }else{
            geometry = tmp;
            index = i;
          }
        }
      }
      if(itemGridGeometry.crossAxisExtent > geometry.crossAxisExtent){
        index = -1;
      }
    }

    return index;
  }
}

///每个section的布局信息
class PageGridGeometry{

  ///主轴起始偏移量
  final double scrollOffset;

  ///主轴末端偏移量
  final double endScrollOffset;

  ///当前section页码
  final int pageIndex;

  ///当前section第一个子视图下标
  final int firstChildIndex;

  ///当前section
  late GridSectionInfo _sectionInfo;

  ///行布局信息
  late RowGridGeometry rowGridGeometry;

  PageGridGeometry({
    this.scrollOffset = 0,
    this.endScrollOffset = 0,
    this.pageIndex = 0,
    this.firstChildIndex = 0,
    required GridSectionInfo sectionInfo,
    RowGridGeometry? rowGridGeometry
  }){
    _sectionInfo = sectionInfo;
    if(rowGridGeometry == null){
      rowGridGeometry = RowGridGeometry(scrollOffset: scrollOffset);
    }
    this.rowGridGeometry = rowGridGeometry;
  }

  ///item布局信息
  Map<int, ItemGridGeometry> itemGeometries = HashMap();

  ///是否可用
  bool isAvailable(double scrollOffset, int index){
    return scrollOffset < endScrollOffset;
  }

  ///根据item大小获取下一个item的位置 如果point.x < 0 ，表示没有空余的位置放item了
  void setupScrollOffset(ItemGridGeometry itemGridGeometry, SliverConstraints constraints, GridSectionInfo sectionInfo, int index){

    //分区不一样了
    if(sectionInfo.sectionBegin == index || sectionInfo.isFooter(index)){
      rowGridGeometry.newLine(_sectionInfo, sectionInfo, index);
      _sectionInfo = sectionInfo;
      _newLine(itemGridGeometry, constraints, index);
      return;
    }

    //该行没有其他item
    if(rowGridGeometry.crossAxisOffset == 0){
      _newLine(itemGridGeometry, constraints, index);
      return;
    }

    if(itemGridGeometry.crossAxisExtent + _sectionInfo.sectionInsets.right + _sectionInfo.crossAxisSpacing + rowGridGeometry.crossAxisOffset > constraints.crossAxisExtent){
      //这一行已经没有位置可以放item了
      if(rowGridGeometry.outermostItemGeometries.length < 2){
        rowGridGeometry.newLine(_sectionInfo, sectionInfo, index);
        _newLine(itemGridGeometry, constraints, index);
      }else{
        int index = rowGridGeometry.traverseOutermostItemGeometries(itemGridGeometry);
        if(index == -1){
          rowGridGeometry.newLine(_sectionInfo, sectionInfo, index);
          _newLine(itemGridGeometry, constraints, index);
        }else{
          ItemGridGeometry geometry = rowGridGeometry.outermostItemGeometries[index];
          itemGridGeometry.crossAxisOffset = geometry.crossAxisOffset;
          itemGridGeometry.scrollOffset = geometry.mainEnd + _sectionInfo.mainAxisSpacing;

          if(itemGridGeometry.crossAxisExtent < geometry.crossAxisExtent){
            //只挡住上面的item的一部分
            geometry.crossAxisOffset = itemGridGeometry.crossEnd + _sectionInfo.crossAxisSpacing;
            geometry.crossAxisExtent -= itemGridGeometry.crossAxisExtent + _sectionInfo.crossAxisSpacing;
          }else {
            //已完全挡住上一个item
            rowGridGeometry.outermostItemGeometries.removeAt(index);
          }

          //添加新的
          ItemGridGeometry tmp = itemGridGeometry.copyWith();
          rowGridGeometry.outermostItemGeometries.insert(index, tmp);
          rowGridGeometry.updateEndGeometry(tmp);

          //合并相同高度的item
          combineTheSameExtentItem(index);
        }
      }
    }else {
      //右边还有位置可以放item
      itemGridGeometry.crossAxisOffset = rowGridGeometry.crossAxisOffset + _sectionInfo.crossAxisSpacing;
      itemGridGeometry.scrollOffset = rowGridGeometry.scrollOffset;
      rowGridGeometry.crossAxisOffset = itemGridGeometry.crossEnd;

      if(rowGridGeometry.outermostItemGeometries.length == 0) {
        rowGridGeometry.outermostItemGeometries.add(itemGridGeometry.copyWith());
      }else {
        //相邻的item等高，合并
        ItemGridGeometry lastGeometry = rowGridGeometry.outermostItemGeometries.last;
        if(itemGridGeometry.mainAxisExtent == lastGeometry.mainAxisExtent) {
          lastGeometry.crossAxisExtent += itemGridGeometry.crossAxisExtent + _sectionInfo.crossAxisSpacing;
        }else {
          rowGridGeometry.outermostItemGeometries.add(itemGridGeometry.copyWith());
        }
      }
      rowGridGeometry.updateEndGeometry(itemGridGeometry);
    }
  }

  void _newLine(ItemGridGeometry itemGridGeometry, SliverConstraints constraints, int index){
    itemGridGeometry.scrollOffset = rowGridGeometry.scrollOffset;
    itemGridGeometry.crossAxisOffset = _sectionInfo.isItem(index) ? _sectionInfo.sectionInsets.left : 0;
    rowGridGeometry.crossAxisOffset = itemGridGeometry.crossEnd;

    rowGridGeometry.outermostItemGeometries.add(itemGridGeometry.copyWith());
    rowGridGeometry.updateEndGeometry(itemGridGeometry);
  }

  ///合并相邻的相同高度的item
  void combineTheSameExtentItem(int index) {
    ItemGridGeometry geometry = rowGridGeometry.outermostItemGeometries[index];
    if(index > 0) {
      //前一个
      ItemGridGeometry previousGeometry = rowGridGeometry.outermostItemGeometries[index - 1];
      if((geometry.mainEnd - previousGeometry.mainEnd).abs() < 1.0) {
        previousGeometry.crossAxisOffset = math.min(geometry.crossAxisOffset, previousGeometry.crossAxisOffset);
        previousGeometry.crossAxisExtent += geometry.crossAxisExtent + _sectionInfo.crossAxisSpacing;

        //防止出现白边
        if(_sectionInfo.crossAxisSpacing == 0) {
          if(previousGeometry.mainEnd > geometry.mainEnd) {
            geometry.mainAxisExtent += previousGeometry.mainEnd - geometry.mainEnd;
          }else if(geometry.mainEnd > previousGeometry.mainEnd) {
            previousGeometry.mainAxisExtent += geometry.mainEnd - previousGeometry.mainEnd;
          }
        }

        geometry = previousGeometry;
        rowGridGeometry.outermostItemGeometries.removeAt(index);
      }
    }

    if(index + 1 < rowGridGeometry.outermostItemGeometries.length) {
      //后一个
      ItemGridGeometry nextGeometry = rowGridGeometry.outermostItemGeometries[index + 1];
      if((geometry.mainEnd - nextGeometry.mainEnd).abs() < 1.0) {
        nextGeometry.crossAxisOffset = math.min(geometry.crossAxisOffset, nextGeometry.crossAxisOffset);
        nextGeometry.crossAxisExtent += geometry.crossAxisExtent + _sectionInfo.crossAxisSpacing;

        //防止出现白边
        if(_sectionInfo.crossAxisSpacing == 0) {
          if(nextGeometry.mainEnd > geometry.mainEnd) {
            geometry.mainAxisExtent += nextGeometry.mainEnd - geometry.mainEnd;
          }else if(geometry.mainEnd > nextGeometry.mainEnd) {
            nextGeometry.mainAxisExtent += geometry.mainEnd - nextGeometry.mainEnd;
          }
        }

        rowGridGeometry.outermostItemGeometries.removeAt(index);
      }
    }
  }
}
