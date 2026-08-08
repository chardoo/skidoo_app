import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the album's one-shot "open the shared photo" logic: the viewer must
/// receive the WHOLE list and the right index, so a shared photo swipes on to
/// the next exactly like a tapped one.
class _Album extends StatefulWidget {
  const _Album({required this.pages, this.openPictureId});
  /// Successive pages of ids, delivered one per tick — the grid pages.
  final List<List<String>> pages;
  final String? openPictureId;
  @override
  State<_Album> createState() => _AlbumState();
}

class _AlbumState extends State<_Album> {
  final List<String> _photos = [];
  bool _handled = false;
  int _page = 0;

  static List<String>? openedWith;
  static int? openedIndex;

  @override
  void initState() {
    super.initState();
    openedWith = null;
    openedIndex = null;
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_page >= widget.pages.length) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    setState(() => _photos.addAll(widget.pages[_page++]));
    _maybeOpen();
  }

  bool get _hasNext => _page < widget.pages.length;

  void _maybeOpen() {
    final wanted = widget.openPictureId;
    if (wanted == null || _handled || _photos.isEmpty) return;
    final index = _photos.indexOf(wanted);
    if (index < 0) {
      if (_hasNext) _loadNextPage();
      return;
    }
    _handled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openedWith = List.of(_photos);
      openedIndex = index;
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: Text('viewer:$wanted'))));
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('album:${_photos.length}'));
}

void main() {
  testWidgets('shared photo opens inside the album, with the full list',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: const _Album(pages: [
        ['a', 'b', 'c']
      ], openPictureId: 'b'),
    ));
    await t.pumpAndSettle();

    expect(find.text('viewer:b'), findsOneWidget);
    expect(_AlbumState.openedWith, ['a', 'b', 'c'],
        reason: 'the viewer must get every photo, not just the shared one');
    expect(_AlbumState.openedIndex, 1, reason: 'positioned on the shared photo');
  });

  testWidgets('pages until it finds a photo that is not on the first page',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: const _Album(pages: [
        ['a', 'b'],
        ['c', 'd'],
      ], openPictureId: 'd'),
    ));
    await t.pumpAndSettle();

    expect(find.text('viewer:d'), findsOneWidget);
    expect(_AlbumState.openedWith, ['a', 'b', 'c', 'd']);
    expect(_AlbumState.openedIndex, 3);
  });

  testWidgets('a photo the album no longer has leaves you on the grid',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: const _Album(pages: [
        ['a', 'b']
      ], openPictureId: 'gone'),
    ));
    await t.pumpAndSettle();

    expect(find.textContaining('viewer:'), findsNothing);
    expect(find.text('album:2'), findsOneWidget);
  });

  testWidgets('no openPictureId opens nothing', (t) async {
    await t.pumpWidget(MaterialApp(
      home: const _Album(pages: [
        ['a', 'b']
      ]),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('viewer:'), findsNothing);
  });
}
