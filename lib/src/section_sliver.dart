import 'dart:collection';
import 'package:flutter_section_list/src/section_sliver_multi_box_adapter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A base class for sliver that have multiple box children.
///
/// Helps subclasses build their children lazily using a [SliverChildDelegate].
///
/// The widgets returned by the [delegate] are cached and the delegate is only
/// consulted again if it changes and the new delegate's [shouldRebuild] method
/// returns true.
abstract class SectionSliverMultiBoxAdaptorWidget extends SliverWithKeepAliveWidget {
  /// Initializes fields for subclasses.
  const SectionSliverMultiBoxAdaptorWidget({
    Key key,
    @required this.delegate,
  }) : assert(delegate != null),
        super(key: key);

  /// {@template flutter.widgets.sliverMultiBoxAdaptor.delegate}
  /// The delegate that provides the children for this widget.
  ///
  /// The children are constructed lazily using this delegate to avoid creating
  /// more children than are visible through the [Viewport].
  ///
  /// See also:
  ///
  ///  * [SliverChildBuilderDelegate] and [SliverChildListDelegate], which are
  ///    commonly used subclasses of [SliverChildDelegate] that use a builder
  ///    callback and an explicit child list, respectively.
  /// {@endtemplate}
  final SliverChildDelegate delegate;

  @override
  SectionSliverMultiBoxAdaptorElement createElement() => SectionSliverMultiBoxAdaptorElement(this);

  @override
  SectionRenderSliverMultiBoxAdaptor createRenderObject(BuildContext context);

  /// Returns an estimate of the max scroll extent for all the children.
  ///
  /// Subclasses should override this function if they have additional
  /// information about their max scroll extent.
  ///
  /// This is used by [SliverMultiBoxAdaptorElement] to implement part of the
  /// [RenderSliverBoxChildManager] API.
  ///
  /// The default implementation defers to [delegate] via its
  /// [SliverChildDelegate.estimateMaxScrollOffset] method.
  double estimateMaxScrollOffset(
      SliverConstraints constraints,
      int firstIndex,
      int lastIndex,
      double leadingScrollOffset,
      double trailingScrollOffset,
      ) {
    assert(lastIndex >= firstIndex);
    return delegate.estimateMaxScrollOffset(
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SliverChildDelegate>('delegate', delegate));
  }
}


/// An element that lazily builds children for a [SliverMultiBoxAdaptorWidget].
///
/// Implements [RenderSliverBoxChildManager], which lets this element manage
/// the children of subclasses of [RenderSliverMultiBoxAdaptor].
class SectionSliverMultiBoxAdaptorElement extends RenderObjectElement implements RenderSliverBoxChildManager {
  /// Creates an element that lazily builds children for the given widget.
  SectionSliverMultiBoxAdaptorElement(SectionSliverMultiBoxAdaptorWidget widget) : super(widget);

  @override
  SectionSliverMultiBoxAdaptorWidget get widget => super.widget as SectionSliverMultiBoxAdaptorWidget;

  @override
  SectionRenderSliverMultiBoxAdaptor get renderObject => super.renderObject as SectionRenderSliverMultiBoxAdaptor;

  @override
  void update(covariant SectionSliverMultiBoxAdaptorWidget newWidget) {
    final SectionSliverMultiBoxAdaptorWidget oldWidget = widget;
    super.update(newWidget);
    final SliverChildDelegate newDelegate = newWidget.delegate;
    final SliverChildDelegate oldDelegate = oldWidget.delegate;
    if (newDelegate != oldDelegate &&
        (newDelegate.runtimeType != oldDelegate.runtimeType || newDelegate.shouldRebuild(oldDelegate)))
      performRebuild();
  }

  // We inflate widgets at two different times:
  //  1. When we ourselves are told to rebuild (see performRebuild).
  //  2. When our render object needs a new child (see createChild).
  // In both cases, we cache the results of calling into our delegate to get the widget,
  // so that if we do case 2 later, we don't call the builder again.
  // Any time we do case 1, though, we reset the cache.

  final Map<int, Widget> _childWidgets = HashMap<int, Widget>();
  final SplayTreeMap<int, Element> _childElements = SplayTreeMap<int, Element>();
  RenderBox _currentBeforeChild;

  @override
  void performRebuild() {
    _childWidgets.clear(); // Reset the cache, as described above.
    super.performRebuild();
    _currentBeforeChild = null;
    assert(_currentlyUpdatingChildIndex == null);
    try {
      final SplayTreeMap<int, Element> newChildren = SplayTreeMap<int, Element>();
      final Map<int, double> indexToLayoutOffset = HashMap<int, double>();

      void processElement(int index) {
        _currentlyUpdatingChildIndex = index;
        if (_childElements[index] != null && _childElements[index] != newChildren[index]) {
          // This index has an old child that isn't used anywhere and should be deactivated.
          _childElements[index] = updateChild(_childElements[index], null, index);
        }
        final Element newChild = updateChild(newChildren[index], _build(index), index);
        if (newChild != null) {
          _childElements[index] = newChild;
          final SectionSliverMultiBoxAdaptorParentData parentData = newChild.renderObject.parentData as SectionSliverMultiBoxAdaptorParentData;
          if (index == 0) {
            parentData.layoutOffset = 0.0;
          } else if (indexToLayoutOffset.containsKey(index)) {
            parentData.layoutOffset = indexToLayoutOffset[index];
          }
          if (!parentData.keptAlive)
            _currentBeforeChild = newChild.renderObject as RenderBox;
        } else {
          _childElements.remove(index);
        }
      }
      for (final int index in _childElements.keys.toList()) {
        final Key key = _childElements[index].widget.key;
        final int newIndex = key == null ? null : widget.delegate.findIndexByKey(key);
        final SectionSliverMultiBoxAdaptorParentData childParentData =
        _childElements[index].renderObject?.parentData as SectionSliverMultiBoxAdaptorParentData;

        if (childParentData != null && childParentData.layoutOffset != null)
          indexToLayoutOffset[index] = childParentData.layoutOffset;

        if (newIndex != null && newIndex != index) {
          // The layout offset of the child being moved is no longer accurate.
          if (childParentData != null)
            childParentData.layoutOffset = null;

          newChildren[newIndex] = _childElements[index];
          // We need to make sure the original index gets processed.
          newChildren.putIfAbsent(index, () => null);
          // We do not want the remapped child to get deactivated during processElement.
          _childElements.remove(index);
        } else {
          newChildren.putIfAbsent(index, () => _childElements[index]);
        }
      }

      renderObject.debugChildIntegrityEnabled = false; // Moving children will temporary violate the integrity.
      newChildren.keys.forEach(processElement);
      if (_didUnderflow) {
        final int lastKey = _childElements.lastKey() ?? -1;
        final int rightBoundary = lastKey + 1;
        newChildren[rightBoundary] = _childElements[rightBoundary];
        processElement(rightBoundary);
      }
    } finally {
      _currentlyUpdatingChildIndex = null;
      renderObject.debugChildIntegrityEnabled = true;
    }
  }

  Widget _build(int index) {
    return _childWidgets.putIfAbsent(index, () => widget.delegate.build(this, index));
  }

  @override
  void createChild(int index, { @required RenderBox after }) {
    assert(_currentlyUpdatingChildIndex == null);
    owner.buildScope(this, () {
      final bool insertFirst = after == null;
      assert(insertFirst || _childElements[index-1] != null);
      _currentBeforeChild = insertFirst ? null : (_childElements[index-1].renderObject as RenderBox);
      Element newChild;
      try {
        _currentlyUpdatingChildIndex = index;
        newChild = updateChild(_childElements[index], _build(index), index);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
    });
  }

  RenderBox createOneChild(int index, int afterIndex, { @required RenderBox after }) {
    assert(_currentlyUpdatingChildIndex == null);
    RenderBox child;
    owner.buildScope(this, () {
      final bool insertFirst = after == null;
      assert(insertFirst || _childElements[afterIndex-1] != null);
      _currentBeforeChild = insertFirst ? null : (_childElements[afterIndex-1].renderObject as RenderBox);
      Element newChild;
      try {
        _currentlyUpdatingChildIndex = index;
        newChild = updateChild(_childElements[index], _build(index), index);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
      child = newChild.renderObject;
    });

    return child;
  }

  @override
  Element updateChild(Element child, Widget newWidget, dynamic newSlot) {
    final SectionSliverMultiBoxAdaptorParentData oldParentData = child?.renderObject?.parentData as SectionSliverMultiBoxAdaptorParentData;
    final Element newChild = super.updateChild(child, newWidget, newSlot);
    final SectionSliverMultiBoxAdaptorParentData newParentData = newChild?.renderObject?.parentData as SectionSliverMultiBoxAdaptorParentData;

    // Preserve the old layoutOffset if the renderObject was swapped out.
    if (oldParentData != newParentData && oldParentData != null && newParentData != null) {
      newParentData.layoutOffset = oldParentData.layoutOffset;
    }
    return newChild;
  }

  @override
  void forgetChild(Element child) {
    assert(child != null);
    assert(child.slot != null);
    assert(_childElements.containsKey(child.slot));
    _childElements.remove(child.slot);
    super.forgetChild(child);
  }

  @override
  void removeChild(RenderBox child) {
    final int index = renderObject.indexOf(child);
    assert(_currentlyUpdatingChildIndex == null);
    assert(index >= 0);
    owner.buildScope(this, () {
      assert(_childElements.containsKey(index));
      try {
        _currentlyUpdatingChildIndex = index;
        final Element result = updateChild(_childElements[index], null, index);
        assert(result == null);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      _childElements.remove(index);
      assert(!_childElements.containsKey(index));
    });
  }

  static double _extrapolateMaxScrollOffset(
      int firstIndex,
      int lastIndex,
      double leadingScrollOffset,
      double trailingScrollOffset,
      int childCount,
      ) {
    if (lastIndex == childCount - 1)
      return trailingScrollOffset;
    final int reifiedCount = lastIndex - firstIndex + 1;
    final double averageExtent = (trailingScrollOffset - leadingScrollOffset) / reifiedCount;
    final int remainingCount = childCount - lastIndex - 1;
    return trailingScrollOffset + averageExtent * remainingCount;
  }

  @override
  double estimateMaxScrollOffset(
      SliverConstraints constraints, {
        int firstIndex,
        int lastIndex,
        double leadingScrollOffset,
        double trailingScrollOffset,
      }) {
    final int childCount = this.childCount;
    if (childCount == null)
      return double.infinity;
    return widget.estimateMaxScrollOffset(
      constraints,
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
    ) ?? _extrapolateMaxScrollOffset(
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
      childCount,
    );
  }

  @override
  int get childCount => widget.delegate.estimatedChildCount;

  @override
  void didStartLayout() {
    assert(debugAssertChildListLocked());
  }

  @override
  void didFinishLayout() {
    assert(debugAssertChildListLocked());
    final int firstIndex = _childElements.firstKey() ?? 0;
    final int lastIndex = _childElements.lastKey() ?? 0;
    widget.delegate.didFinishLayout(firstIndex, lastIndex);
  }

  int _currentlyUpdatingChildIndex;

  @override
  bool debugAssertChildListLocked() {
    assert(_currentlyUpdatingChildIndex == null);
    return true;
  }

  @override
  void didAdoptChild(RenderBox child) {
    assert(_currentlyUpdatingChildIndex != null);
    final SectionSliverMultiBoxAdaptorParentData childParentData = child.parentData as SectionSliverMultiBoxAdaptorParentData;
    childParentData.index = _currentlyUpdatingChildIndex;
  }

  bool _didUnderflow = false;

  @override
  void setDidUnderflow(bool value) {
    _didUnderflow = value;
  }

  @override
  void insertChildRenderObject(covariant RenderObject child, int slot) {
    assert(slot != null);
    assert(_currentlyUpdatingChildIndex == slot);
    assert(renderObject.debugValidateChild(child));
    renderObject.insert(child as RenderBox, after: _currentBeforeChild);
    assert(() {
      final SectionSliverMultiBoxAdaptorParentData childParentData = child.parentData as SectionSliverMultiBoxAdaptorParentData;
      assert(slot == childParentData.index);
      return true;
    }());
  }

  @override
  void moveChildRenderObject(covariant RenderObject child, int slot) {
    assert(slot != null);
    assert(_currentlyUpdatingChildIndex == slot);
    renderObject.move(child as RenderBox, after: _currentBeforeChild);
  }

  @override
  void removeChildRenderObject(covariant RenderObject child) {
    assert(_currentlyUpdatingChildIndex != null);
    renderObject.remove(child as RenderBox);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    // The toList() is to make a copy so that the underlying list can be modified by
    // the visitor:
    assert(!_childElements.values.any((Element child) => child == null));
    _childElements.values.toList().forEach(visitor);
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    _childElements.values.where((Element child) {
      final SectionSliverMultiBoxAdaptorParentData parentData = child.renderObject.parentData as SectionSliverMultiBoxAdaptorParentData;
      double itemExtent;
      switch (renderObject.constraints.axis) {
        case Axis.horizontal:
          itemExtent = child.renderObject.paintBounds.width;
          break;
        case Axis.vertical:
          itemExtent = child.renderObject.paintBounds.height;
          break;
      }

      return parentData.layoutOffset != null &&
          parentData.layoutOffset < renderObject.constraints.scrollOffset + renderObject.constraints.remainingPaintExtent &&
          parentData.layoutOffset + itemExtent > renderObject.constraints.scrollOffset;
    }).forEach(visitor);
  }
}