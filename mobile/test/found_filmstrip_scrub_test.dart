import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scrub maths and the loop-guard, isolated from images and theming.
class _Strip extends StatefulWidget {
  const _Strip({required this.count, required this.onScrub, required this.active});
  final int count;
  final int active;
  final ValueChanged<int> onScrub;
  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  final _c = ScrollController();
  bool _scrubbing = false;
  int? _last;
  static const double itemExtent = 72;

  double _offsetFor(int i) {
    final v = _c.position.viewportDimension;
    return ((i * itemExtent) - (v / 2) + (itemExtent / 2))
        .clamp(0.0, _c.position.maxScrollExtent);
  }

  int _indexAtCentre() {
    final v = _c.position.viewportDimension;
    return (((_c.offset + (v / 2) - (itemExtent / 2)) / itemExtent))
        .round()
        .clamp(0, widget.count - 1);
  }

  bool _onNotification(ScrollNotification n) {
    if (!_c.hasClients) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _scrubbing = true;
      _last = widget.active;
    } else if (n is ScrollUpdateNotification && _scrubbing) {
      final i = _indexAtCentre();
      if (i != _last) {
        _last = i;
        widget.onScrub(i);
      }
    } else if (n is ScrollEndNotification && _scrubbing) {
      _scrubbing = false;
      final i = _indexAtCentre();
      if (i != _last) {
        _last = i;
        widget.onScrub(i);
      }
      _c.animateTo(_offsetFor(i),
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: ListView.builder(
            controller: _c,
            scrollDirection: Axis.horizontal,
            itemCount: widget.count,
            itemBuilder: (_, i) =>
                SizedBox(width: itemExtent, child: Center(child: Text('$i'))),
          ),
        ),
      );
}

void main() {
  testWidgets('dragging the strip selects photos as it passes them',
      (t) async {
    final selected = <int>[];
    var active = 0;

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => _Strip(
            count: 20,
            active: active,
            onScrub: (i) => setState(() {
              active = i;
              selected.add(i);
            }),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.drag(find.byType(ListView), const Offset(-300, 0));
    await t.pumpAndSettle();

    expect(selected, isNotEmpty, reason: 'scrubbing must change the photo');
    expect(selected, equals(List.of(selected)..sort()),
        reason: 'selection advances in order, never jumps around');
    expect(active, greaterThan(0));
  });

  testWidgets('reports each photo once, not once per scroll frame', (t) async {
    final selected = <int>[];
    var active = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => _Strip(
            count: 20,
            active: active,
            onScrub: (i) => setState(() {
              active = i;
              selected.add(i);
            }),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.drag(find.byType(ListView), const Offset(-400, 0));
    await t.pumpAndSettle();

    expect(selected.toSet().length, selected.length,
        reason: 'no duplicates — one report per thumbnail: $selected');
  });
}
