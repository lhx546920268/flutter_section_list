

import 'package:flutter_section_list/src/geometry.dart';
import 'package:flutter_section_list/src/section.dart';
import 'package:flutter_section_list/src/section_adapter.dart';
import 'package:flutter_section_list/src/section_sliver.dart';
import 'package:flutter_section_list/src/section_sliver_multi_box_adapter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'dart:collection';
import 'dart:math' as math;

///可分区的列表视图
class SectionListView extends BoxScrollView {

  final SectionAdapter adapter;
  final SliverChildDelegate childrenDelegate;
  final bool dataChange;

  SectionListView.builder({
    Key key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController controller,
    bool primary,
    ScrollPhysics physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry padding,
    @required this.adapter,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    double cacheExtent,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
  }): assert(adapter != null), dataChange = adapter.notifyDataChange(),
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
        dragStartBehavior: dragStartBehavior,
      );

  @override
  Widget buildChildLayout(BuildContext context) {
    return SectionSliverList(delegate: childrenDelegate, adapter: adapter,);
  }
}

class SectionSliverList extends SectionSliverMultiBoxAdaptorWidget {

  final SectionAdapter adapter;

  const SectionSliverList({
    Key key,
    @required SliverChildDelegate delegate,
    @required this.adapter,
  }) : super(key: key, delegate: delegate);

  @override
  SectionRenderSliverList createRenderObject(BuildContext context) {
    final SectionSliverMultiBoxAdaptorElement element = context as SectionSliverMultiBoxAdaptorElement;
    return SectionRenderSliverList(childManager: element, adapter: this.adapter);
  }

  @override
  void updateRenderObject(BuildContext context, SectionRenderSliverList renderObject) {
    renderObject.clearCache(adapter);
  }
}

class SectionRenderSliverList extends SectionRenderSliverMultiBoxAdaptor {

  SectionAdapter _adapter;

  ///当前置顶的子视图
  RenderBox _currentStickChild;

  ///主轴缓存
  SplayTreeMap<int, ItemGeometry> _itemGeometries= SplayTreeMap();

  SectionRenderSliverList({
    @required RenderSliverBoxChildManager childManager,
    @required SectionAdapter adapter,
  }) : super(childManager: childManager){
    _adapter = adapter;
  }

  ///清除缓存
  void clearCache(SectionAdapter adapter){
    _adapter = adapter;
    _itemGeometries.clear();
  }

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    _adapter.crossAxisExtent = constraints.crossAxisExtent;

    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;
    final BoxConstraints childConstraints = constraints.asBoxConstraints();
    int leadingGarbage = 0;
    int trailingGarbage = 0;
    bool reachedEnd = false;

    if(_currentStickChild != null){
      collectGarbageItem(_currentStickChild);
      _currentStickChild = null;
    }

    // This algorithm in principle is straight-forward: find the first child
    // that overlaps the given scrollOffset, creating more children at the top
    // of the list if necessary, then walk down the list updating and laying out
    // each child and adding more at the end if necessary until we have enough
    // children to cover the entire viewport.
    //
    // It is complicated by one minor issue, which is that any time you update
    // or create a child, it's possible that the some of the children that
    // haven't yet been laid out will be removed, leaving the list in an
    // inconsistent state, and requiring that missing nodes be recreated.
    //
    // To keep this mess tractable, this algorithm starts from what is currently
    // the first child, if any, and then walks up and/or down from there, so
    // that the nodes that might get removed are always at the edges of what has
    // already been laid out.

    // Make sure we have at least one child to start from.
    if (firstChild == null) {
      if (!addInitialChild()) {
        // There are no children.
        geometry = SliverGeometry.zero;
        childManager.didFinishLayout();
        return;
      }
    }

    // We have at least one child.

    // These variables track the range of children that we have laid out. Within
    // this range, the children have consecutive indices. Outside this range,
    // it's possible for a child to get removed without notice.
    RenderBox leadingChildWithLayout, trailingChildWithLayout;

    RenderBox earliestUsefulChild = firstChild;

    // A firstChild with null layout offset is likely a result of children
    // reordering.
    //
    // We rely on firstChild to have accurate layout offset. In the case of null
    // layout offset, we have to find the first child that has valid layout
    // offset.
    if (childScrollOffset(firstChild) == null) {
      int leadingChildrenWithoutLayoutOffset = 0;
      while (childScrollOffset(earliestUsefulChild) == null) {
        earliestUsefulChild = childAfter(firstChild);
        leadingChildrenWithoutLayoutOffset += 1;
      }
      // We should be able to destroy children with null layout offset safely,
      // because they are likely outside of viewport
      collectGarbage(leadingChildrenWithoutLayoutOffset, 0);
      assert(firstChild != null);
    }

    // Find the last child that is at or before the scrollOffset.
    earliestUsefulChild = firstChild;
    for (double earliestScrollOffset = childScrollOffset(earliestUsefulChild);
    earliestScrollOffset > scrollOffset;
    earliestScrollOffset = childScrollOffset(earliestUsefulChild)) {
      // We have to add children before the earliestUsefulChild.
      earliestUsefulChild = insertAndLayoutLeadingChild(childConstraints, parentUsesSize: true);

      if (earliestUsefulChild == null) {
        final SectionSliverMultiBoxAdaptorParentData childParentData = firstChild.parentData as SectionSliverMultiBoxAdaptorParentData;
        childParentData.layoutOffset = 0.0;

        if (scrollOffset == 0.0) {
          // insertAndLayoutLeadingChild only lays out the children before
          // firstChild. In this case, nothing has been laid out. We have
          // to lay out firstChild manually.
          firstChild.layout(childConstraints, parentUsesSize: true);
          earliestUsefulChild = firstChild;
          leadingChildWithLayout = earliestUsefulChild;
          trailingChildWithLayout ??= earliestUsefulChild;
          break;
        } else {
          // We ran out of children before reaching the scroll offset.
          // We must inform our parent that this sliver cannot fulfill
          // its contract and that we need a scroll offset correction.
          geometry = SliverGeometry(
            scrollOffsetCorrection: -scrollOffset,
          );
          return;
        }
      }

      final double firstChildScrollOffset = earliestScrollOffset - paintExtentOf(firstChild);
      // firstChildScrollOffset may contain double precision error
      if (firstChildScrollOffset < -precisionErrorTolerance) {
        // The first child doesn't fit within the viewport (underflow) and
        // there may be additional children above it. Find the real first child
        // and then correct the scroll position so that there's room for all and
        // so that the trailing edge of the original firstChild appears where it
        // was before the scroll offset correction.
        // TODO(hansmuller): do this work incrementally, instead of all at once,
        // i.e. find a way to avoid visiting ALL of the children whose offset
        // is < 0 before returning for the scroll correction.
        double correction = 0.0;
        while (earliestUsefulChild != null) {
          assert(firstChild == earliestUsefulChild);
          correction += paintExtentOf(firstChild);
          earliestUsefulChild = insertAndLayoutLeadingChild(childConstraints, parentUsesSize: true);
        }
        earliestUsefulChild = firstChild;
        if ((correction - earliestScrollOffset).abs() > precisionErrorTolerance) {
          geometry = SliverGeometry(
            scrollOffsetCorrection: correction - earliestScrollOffset,
          );
          final SectionSliverMultiBoxAdaptorParentData childParentData = firstChild.parentData as SectionSliverMultiBoxAdaptorParentData;
          childParentData.layoutOffset = 0.0;
          return;
        }
      }

      final SectionSliverMultiBoxAdaptorParentData childParentData = earliestUsefulChild.parentData as SectionSliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = firstChildScrollOffset;
      assert(earliestUsefulChild == firstChild);
      leadingChildWithLayout = earliestUsefulChild;
      trailingChildWithLayout ??= earliestUsefulChild;
    }

    // At this point, earliestUsefulChild is the first child, and is a child
    // whose scrollOffset is at or before the scrollOffset, and
    // leadingChildWithLayout and trailingChildWithLayout are either null or
    // cover a range of render boxes that we have laid out with the first being
    // the same as earliestUsefulChild and the last being either at or after the
    // scroll offset.

    assert(earliestUsefulChild == firstChild);
    assert(childScrollOffset(earliestUsefulChild) <= scrollOffset);

    // Make sure we've laid out at least one child.
    if (leadingChildWithLayout == null) {
      earliestUsefulChild.layout(childConstraints, parentUsesSize: true);
      leadingChildWithLayout = earliestUsefulChild;
      trailingChildWithLayout = earliestUsefulChild;
    }

    // Here, earliestUsefulChild is still the first child, it's got a
    // scrollOffset that is at or before our actual scrollOffset, and it has
    // been laid out, and is in fact our leadingChildWithLayout. It's possible
    // that some children beyond that one have also been laid out.

    //当前section
    SectionInfo currentSectionInfo;
    double currentSectionScrollOffset = double.infinity;

    bool inLayoutRange = true;
    RenderBox child = earliestUsefulChild;
    int index = indexOf(child);

    double endScrollOffset = childScrollOffset(child) + paintExtentOf(child);
    if(endScrollOffset >= constraints.scrollOffset){
      currentSectionInfo = _adapter.sectionInfoForPosition(index);
      currentSectionScrollOffset = endScrollOffset;
    }

    _itemGeometries.putIfAbsent(index, () => ItemGeometry(
        scrollOffset: childScrollOffset(child),
        mainAxisExtent: paintExtentOf(child),
    ));

    bool advance() { // returns true if we advanced, false if we have no more children
      // This function is used in two different places below, to avoid code duplication.
      assert(child != null);
      if (child == trailingChildWithLayout)
        inLayoutRange = false;
      child = childAfter(child);
      if (child == null)
        inLayoutRange = false;
      index += 1;
      if (!inLayoutRange) {
        if (child == null || indexOf(child) != index) {
          // We are missing a child. Insert it (and lay it out) if possible.
          child = insertAndLayoutChild(childConstraints,
            after: trailingChildWithLayout,
            parentUsesSize: true,
          );
          if (child == null) {
            // We have run out of children.
            return false;
          }
        } else {
          // Lay out the child.
          child.layout(childConstraints, parentUsesSize: true);
        }
        trailingChildWithLayout = child;
      }
      assert(child != null);
      final SectionSliverMultiBoxAdaptorParentData childParentData = child.parentData as SectionSliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = endScrollOffset;
      assert(childParentData.index == index);
      endScrollOffset = childScrollOffset(child) + paintExtentOf(child);

      if(endScrollOffset >= constraints.scrollOffset && endScrollOffset < currentSectionScrollOffset){
        currentSectionInfo = _adapter.sectionInfoForPosition(index);
        currentSectionScrollOffset = endScrollOffset;
      }

      _itemGeometries.putIfAbsent(index, () => ItemGeometry(
        scrollOffset: childScrollOffset(child),
        mainAxisExtent: paintExtentOf(child),
      ));

      return true;
    }

    // Find the first child that ends after the scroll offset.
    while (endScrollOffset < scrollOffset) {
      leadingGarbage += 1;
      if (!advance()) {
        assert(leadingGarbage == childCount);
        assert(child == null);
        // we want to make sure we keep the last child around so we know the end scroll offset
        collectGarbage(leadingGarbage - 1, 0);
        assert(firstChild == lastChild);
        final double extent = childScrollOffset(lastChild) + paintExtentOf(lastChild);
        geometry = SliverGeometry(
          scrollExtent: extent,
          paintExtent: 0.0,
          maxPaintExtent: extent,
        );
        return;
      }
    }

    // Now find the first child that ends after our end.
    while (endScrollOffset < targetEndScrollOffset) {
      if (!advance()) {
        reachedEnd = true;
        break;
      }
    }

    // Finally count up all the remaining children and label them as garbage.
    if (child != null) {
      child = childAfter(child);
      while (child != null) {
        trailingGarbage += 1;
        child = childAfter(child);
      }
    }

    // At this point everything should be good to go, we just have to clean up
    // the garbage and report the geometry.

    collectGarbage(leadingGarbage, trailingGarbage);

    int firstIndex = indexOf(firstChild);
    int lastIndex = indexOf(lastChild);

    bool hasStick = false;
    if(currentSectionInfo != null){

      //把header置顶
      if(currentSectionInfo.isHeaderStick && currentSectionInfo.isExistHeader){
        ItemGeometry geometry = _itemGeometries[currentSectionInfo.getHeaderPosition()];
        if(geometry.scrollOffset < constraints.scrollOffset){
          int index = currentSectionInfo.getHeaderPosition();
          RenderBox child = addAndLayoutChild(childConstraints, index: index, after: lastChild);

          SectionSliverMultiBoxAdaptorParentData parentData = child.parentData as SectionSliverMultiBoxAdaptorParentData;
          ItemGeometry lastGeometry = _itemGeometries[currentSectionInfo.sectionEnd];
          if(lastGeometry != null){
            parentData.layoutOffset = math.min(constraints.scrollOffset, lastGeometry.mainEnd - geometry.mainAxisExtent);
          }else{
            parentData.layoutOffset = constraints.scrollOffset;
          }

          _currentStickChild = child;
          hasStick = true;
        }
      }
    }
    if(!hasStick){
      _currentStickChild = null;
    }

//    assert(debugAssertChildListIsNonEmptyAndContiguous());
    double estimatedMaxScrollOffset;
    if (reachedEnd) {
      estimatedMaxScrollOffset = endScrollOffset;
    } else {
      estimatedMaxScrollOffset = childManager.estimateMaxScrollOffset(
        constraints,
        firstIndex: firstIndex,
        lastIndex: lastIndex,
        leadingScrollOffset: childScrollOffset(firstChild),
        trailingScrollOffset: endScrollOffset,
      );
      assert(estimatedMaxScrollOffset >= endScrollOffset - childScrollOffset(firstChild));
    }
    final double paintExtent = calculatePaintOffset(
      constraints,
      from: childScrollOffset(firstChild),
      to: endScrollOffset,
    );
    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: childScrollOffset(firstChild),
      to: endScrollOffset,
    );
    final double targetEndScrollOffsetForPaint = constraints.scrollOffset + constraints.remainingPaintExtent;
    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      // Conservative to avoid flickering away the clip during scroll.
      hasVisualOverflow: endScrollOffset > targetEndScrollOffsetForPaint || constraints.scrollOffset > 0.0,
    );

    // We may have started the layout while scrolled to the end, which would not
    // expose a new child.
    if (estimatedMaxScrollOffset == endScrollOffset)
      childManager.setDidUnderflow(true);
    childManager.didFinishLayout();
  }
}