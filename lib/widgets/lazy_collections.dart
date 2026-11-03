import 'package:flutter/material.dart';

/// Keep a row containing keyboard/editing focus alive while it leaves view.
class KeepFocusedAlive extends StatefulWidget {
  const KeepFocusedAlive({super.key, required this.child});
  final Widget child;

  @override
  State<KeepFocusedAlive> createState() => _KeepFocusedAliveState();
}

class _KeepFocusedAliveState extends State<KeepFocusedAlive>
    with AutomaticKeepAliveClientMixin {
  bool _focused = false;
  @override
  bool get wantKeepAlive => _focused;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) {
          if (_focused == focused) return;
          _focused = focused;
          updateKeepAlive();
        },
        child: widget.child);
  }
}

/// Same full-width children as a constrained Column, mounted near the viewport.
class ConstrainedListView extends StatelessWidget {
  const ConstrainedListView(
      {super.key,
      required this.maxWidth,
      required this.children,
      this.padding = const EdgeInsets.all(16)});
  final double maxWidth;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final indices = <Key, int>{
      for (var i = 0; i < children.length; i++)
        if (children[i].key != null) ValueKey<Key>(children[i].key!): i,
    };
    return ListView.builder(
        padding: padding,
        itemCount: children.length,
        findChildIndexCallback: (key) => indices[key],
        itemBuilder: (context, index) => KeepFocusedAlive(
            key: children[index].key == null
                ? null
                : ValueKey<Key>(children[index].key!),
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SizedBox(
                        width: double.infinity, child: children[index])))));
  }
}
