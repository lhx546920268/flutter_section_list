import 'dart:async';
import 'dart:collection';

import 'package:flutter_section_list/src/geometry.dart';
import 'package:flutter_section_list/src/section.dart';
import 'package:flutter_section_list/src/section_adapter.dart';
import 'package:flutter_section_list/src/section_sliver.dart';
import 'package:flutter_section_list/src/section_sliver_multi_box_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ignore: implementation_imports
import 'package:flutter/src/rendering/sliver.dart';
import 'dart:math' as math;

///可分区的网格列表
class SectionGridView extends BoxScrollView {
  ///网格分区适配器
  final SectionGridAdapter adapter;
  final SliverChildDelegate childrenDelegate;
  final bool dataChange;

  SectionGridView.builder({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    required this.adapter,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    double? cacheExtent,
    Clip clipBehavior = Clip.hardEdge,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
  })  : dataChange = adapter.notifyDataChange(),
        childrenDelegate = SliverChildBuilderDelegate(
          (BuildContext context, int position) {
            return adapter.buildItem(context, position);
          },
          childCount: adapter.getItemCount(),
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
        ),
        super(
          key: key,
          scrollDirection: scrollDirection,
          reverse: reverse,
          controller: controller,
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          cacheExtent: cacheExtent,
          semanticChildCount: adapter.getItemCount(),
          clipBehavior: clipBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId
        );

  @override
  Widget buildChildLayout(BuildContext context) {
    return SectionSliverGrid(
      delegate: childrenDelegate,
      adapter: this.adapter,
    );
  }
}

///
class SectionSliverGrid extends SectionSliverMultiBoxAdaptorWidget {
  ///适配器
  final SectionGridAdapter adapter;

  const SectionSliverGrid(
      {Key? key, required SliverChildDelegate delegate, required this.adapter})
      : super(
          key: key,
          delegate: delegate,
        );

  @override
  SectionRenderSliverMultiBoxAdaptor createRenderObject(BuildContext context) {
    final SectionSliverMultiBoxAdaptorElement element =
        context as SectionSliverMultiBoxAdaptorElement;
    return SectionRenderSliverGrid(childManager: element, adapter: adapter);
  }

  @override
  void updateRenderObject(
      BuildContext context, SectionRenderSliverGrid renderObject) {
    renderObject.clearCache(adapter);
  }
}

///
class SectionRenderSliverGrid extends SectionRenderSliverMultiBoxAdaptor {
  ///适配器
  SectionGridAdapter _adapter;

  ///子视图，并不是所有子视图，只是拿来保存firstChild前面的子视图
  List<RenderBox> _children = [];

  ///布局信息缓存
  SplayTreeMap<int, PageGridGeometry> _pageGridGeometries = SplayTreeMap();

  ///缓存页面大小
  int numberOfCachePages = 2;

  ///当前置顶的子视图
  RenderBox? _currentStickChild;

  ///当前
  int? _stickSection;

  SectionRenderSliverGrid(
      {required RenderSliverBoxChildManager childManager,
      required SectionGridAdapter adapter})
      : _adapter = adapter,
        super(childManager: childManager);

  ///清除缓存
  void clearCache(SectionGridAdapter adapter) {
    _adapter = adapter;
    _pageGridGeometries.clear();
    _children.clear();
  }

  @override
  void performLayout() {

    final SliverConstraints constraints = this.constraints;
    _adapter.crossAxisExtent = constraints.crossAxisExtent;
    _adapter.mainAxisExtent = constraints.viewportMainAxisExtent;

    childManager.didStartLayout();
    childManager.setDidUnderflow(false);
    _children.clear();

    //回收当前置顶的header，否则会导致在section切换的时候 添加child的顺序错乱
    if (_currentStickChild != null) {
      collectGarbageItem(_currentStickChild);
      _currentStickChild = null;
    }

    //最少要有一个子视图
    if (firstChild == null) {
      if (!addInitialChild()) {
        // 没有则返回
        geometry = SliverGeometry.zero;
        childManager.didFinishLayout();
        collectGarbage(0, 0);
        return;
      }
    }

    //计算当前偏移量和可见的区域
    final double scrollOffset =
        constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;
    bool reachEnd = false;

    BoxConstraints childConstraint =
        BoxConstraints(minWidth: 0, maxWidth: constraints.crossAxisExtent);

    //确保子视图已计算出大小
    firstChild!.layout(childConstraint, parentUsesSize: true);

    //当前section
    GridSectionInfo? currentSectionInfo;

    //需要布局的大小
    final double pageSize =
        numberOfCachePages * constraints.viewportMainAxisExtent;

    //无论什么时候都得从每一页的第一个子视图开始计算，否则scrollOffset会不准确，这里会按照numberOfCachePages来缓存对应的布局信息
    final int pageIndex = scrollOffset ~/ pageSize;
    PageGridGeometry? pageGridGeometry;
    if (_pageGridGeometries.isEmpty) {
      //刚开始布局，肯定是从0开始
      pageGridGeometry = PageGridGeometry(
          endScrollOffset: pageSize,
          sectionInfo: _adapter.sectionInfoForPosition(0)!);
      _pageGridGeometries[0] = pageGridGeometry;
    } else {
      //获取距离当前页最小的，如果已经存在布局数据，就不应该从第一个item开始布局了
      int currentPageIndex = pageIndex + 1;
      pageGridGeometry = _pageGridGeometries[
          _pageGridGeometries.lastKeyBefore(currentPageIndex)];

      //第一个子视图下标不对，拿上一个的
      while (pageGridGeometry != null && indexOf(firstChild!) < pageGridGeometry.firstChildIndex) {
        currentPageIndex--;
        pageGridGeometry = _pageGridGeometries[
            _pageGridGeometries.lastKeyBefore(currentPageIndex)];
      }
    }

    //当前布局到的位置
    double endScrollOffset = pageGridGeometry!.scrollOffset;
    RenderBox? firstVisibleChild;
    RenderBox? lastVisibleChild;

    _children.add(firstChild!);
    RenderBox? currentFirstChild = firstChild;

    int index = indexOf(firstChild!);

    //获取第一个子视图前面的子视图，并且在当前缓存页的
    while (index > pageGridGeometry.firstChildIndex) {
      index--;
      RenderBox? child =
          insertAndLayoutLeadingChild(childConstraint, parentUsesSize: true);
      if (child != null) {
        _children.add(child);
      } else {
        break;
      }
    }

    GridSectionInfo sectionInfo =
        _adapter.sectionInfoForPosition(indexOf(_children.last))!;
    //设置子视图位置
    ItemGridGeometry setupUpGeometry(RenderBox child) {
      int index = indexOf(child);
      if (!sectionInfo.include(index)) {
        sectionInfo = _adapter.sectionInfoForPosition(index)!;
      }

      //已超过当前缓存页
      if (!pageGridGeometry!.isAvailable(endScrollOffset, index)) {
        PageGridGeometry previous = pageGridGeometry!;
        int pageIndex = previous.pageIndex + 1;
        pageGridGeometry = _pageGridGeometries[pageIndex];

        if (pageGridGeometry == null) {
          pageGridGeometry = PageGridGeometry(
              scrollOffset: pageIndex * pageSize,
              endScrollOffset: (pageIndex + 1) * pageSize,
              pageIndex: pageIndex,
              firstChildIndex: index,
              rowGridGeometry: previous.rowGridGeometry.copyWith(),
              sectionInfo: sectionInfo);
          _pageGridGeometries[pageIndex] = pageGridGeometry!;
        } else if (pageGridGeometry!.firstChildIndex > index) {
          pageGridGeometry = previous;
        }
      }

      ItemGridGeometry? geometry = pageGridGeometry!.itemGeometries[index];
      if (geometry == null) {
        geometry = ItemGridGeometry(
            crossAxisExtent: paintCrossExtentOf(child),
            mainAxisExtent: paintExtentOf(child));
        pageGridGeometry!.setupScrollOffset(
            geometry, constraints, sectionInfo, index);
        pageGridGeometry!.itemGeometries[index] = geometry;
        if (sectionInfo.isHeader(index)) {
          sectionInfo.headerGeometry = geometry;
        }
        sectionInfo.mainEnd = math.max(geometry.mainEnd, geometry.mainEnd);
      }

      SectionSliverMultiBoxAdaptorParentData parentData =
          child.parentData as SectionSliverMultiBoxAdaptorParentData;
      parentData.crossAxisOffset = geometry.crossAxisOffset;
      parentData.layoutOffset = geometry.scrollOffset;

      //拿可见范围内的第一个和最后一个子视图
      if (geometry.mainEnd > scrollOffset &&
          geometry.scrollOffset < targetEndScrollOffset) {
        if (firstVisibleChild == null) {
          firstVisibleChild = child;
        } else if (childScrollOffset(firstVisibleChild!)! >
            geometry.scrollOffset) {
          firstVisibleChild = child;
        }
        if (lastVisibleChild == null) {
          lastVisibleChild = child;
        } else if (childScrollOffset(lastVisibleChild!)! +
                paintExtentOf(lastVisibleChild!) <=
            geometry.mainEnd) {
          lastVisibleChild = child;
        }
      }

      if (currentSectionInfo == null &&
          geometry.mainEnd >= constraints.scrollOffset) {
        currentSectionInfo = sectionInfo;
      }

      return geometry;
    }

    //因为前面是向前遍历，第一个子视图在最后，所以这里反向遍历
    for (RenderBox child in _children.reversed) {
      ItemGridGeometry geometry = setupUpGeometry(child);
      endScrollOffset = math.max(geometry.mainEnd, endScrollOffset);
    }

    RenderBox currentLastChild = _children.first;
    index = indexOf(currentFirstChild!);
    //计算第一个视图后的并且在可见范围内的子视图
    while (endScrollOffset < targetEndScrollOffset) {
      index++;
      RenderBox? child = childAfter(currentLastChild);
      if(child == null || indexOf(child) != index){
        child = insertAndLayoutChild(childConstraint,
            after: currentLastChild, parentUsesSize: true);
      }else{
        child.layout(childConstraint, parentUsesSize: true);
      }

      if (child != null) {
        currentLastChild = child;
        endScrollOffset =
            math.max(setupUpGeometry(child).mainEnd, endScrollOffset);
      } else {
        reachEnd = true;
        break;
      }
    }

    //前后item数据相差过大，导致偏移量大于实际的内容大小，导致无法获取第一个可见的
    if (firstVisibleChild == null) {
      firstVisibleChild = firstChild;
    }

    if (lastVisibleChild == null) {
      lastVisibleChild = lastChild;
    }

    double trailingScrollOffset =
        childScrollOffset(lastVisibleChild!)! + paintExtentOf(lastVisibleChild!);
    double leadingScrollOffset = childScrollOffset(firstVisibleChild!)!;

    //回收不可见的子视图
    collectGarbageItems(firstVisibleChild, lastVisibleChild);

    bool hasStick = false;
    if (currentSectionInfo != null) {
      //把header置顶
      if (currentSectionInfo!.isHeaderStick &&
          currentSectionInfo!.isExistHeader) {
        ItemGridGeometry geometry = currentSectionInfo!.headerGeometry;
        if (geometry.scrollOffset < constraints.scrollOffset) {
          int index = currentSectionInfo!.getHeaderPosition();
          RenderBox? child = addAndLayoutChild(childConstraint,
              index: index, after: lastVisibleChild);

          if(child != null){
            SectionSliverMultiBoxAdaptorParentData parentData =
            child.parentData as SectionSliverMultiBoxAdaptorParentData;
            parentData.layoutOffset = math.min(constraints.scrollOffset,
                currentSectionInfo!.mainEnd - geometry.mainAxisExtent + currentSectionInfo!.sectionInsets.bottom);
            parentData.crossAxisOffset = geometry.crossAxisOffset;
            _currentStickChild = child;
            hasStick = true;
          }
        }

        if(_stickSection != currentSectionInfo!.section){
          _stickSection = currentSectionInfo!.section;
          int? section = _stickSection;
          //必须延迟，否则在回调中setState会抛出异常
          Timer(Duration(milliseconds: 100), () {
            if(_stickSection != null && _stickSection == section){
              _adapter.onSectionHeaderStick(_stickSection!);
            }
          });
        }
      }
    }
    if (!hasStick) {
      _currentStickChild = null;
    }

    double estimatedTotalExtent;
    if (reachEnd) {
      estimatedTotalExtent = trailingScrollOffset;
    } else {
      estimatedTotalExtent = childManager.estimateMaxScrollOffset(
        constraints,
        firstIndex: indexOf(firstVisibleChild!),
        lastIndex: indexOf(lastVisibleChild!),
        leadingScrollOffset: leadingScrollOffset,
        trailingScrollOffset: trailingScrollOffset,
      );
    }

    final double paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );
    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    geometry = SliverGeometry(
      scrollExtent: estimatedTotalExtent,
      paintExtent: paintExtent,
      maxPaintExtent: estimatedTotalExtent,
      cacheExtent: cacheExtent,
      // Conservative to avoid complexity.
      hasVisualOverflow: true,
    );

    // We may have started the layout while scrolled to the end, which
    // would not expose a new child.
    if (estimatedTotalExtent == trailingScrollOffset)
      childManager.setDidUnderflow(true);
    childManager.didFinishLayout();
  }
}
