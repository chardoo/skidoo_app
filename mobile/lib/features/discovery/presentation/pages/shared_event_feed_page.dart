import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A shared event, opened as the feed shows it rather than as a grid of
/// thumbnails.
///
/// A link to an event used to open [SearchEventPhotosPage] — the album. That is
/// the right screen for browsing a shoot you already know about, and the wrong
/// one for arriving at a post somebody sent you: an album opens on a wall of
/// crops, with the photographer, the caption, the reactions and the soundtrack
/// all one level away. The feed card is how this post looks everywhere else in
/// the app, and how the person sharing it saw it when they decided to share.
///
/// Its own page rather than the home feed scrolled to the right index, because
/// a shared event very often is not in your feed at all — it can be older than
/// the window the feed pulls, or simply not something the recommender picked
/// for you. Seeking to it would work sometimes and silently do nothing the rest
/// of the time, which is the worst of both.
///
/// The album has not gone anywhere: the card's own "Explore event photos" opens
/// it, which is the same route a tap takes on any other card.
class SharedEventFeedPage extends StatefulWidget {
  const SharedEventFeedPage({
    super.key,
    required this.eventId,
    this.event,
    this.dataSource,
  });

  /// The event to open. Fetched when [event] is not supplied.
  final String eventId;

  /// Already in hand — from a feed card the app was showing anyway. Skips the
  /// fetch and the spinner with it.
  final EventDiscovery? event;

  /// Injectable so the page can be pumped without an HTTP client behind it.
  final DiscoveryRemoteDataSource? dataSource;

  @override
  State<SharedEventFeedPage> createState() => _SharedEventFeedPageState();
}

class _SharedEventFeedPageState extends State<SharedEventFeedPage> {
  late final _source = widget.dataSource ?? sl<DiscoveryRemoteDataSource>();

  final _activeCardIndex = ValueNotifier<int>(0);

  EventDiscovery? _event;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    if (_event == null) _load();
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await _source.getEventById(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[SharedEventFeed] load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (event != null)
            // The card reads the feed's DiscoveryBloc for reaction state. This
            // page is not the feed, so it brings its own — the card falls back
            // to the counts it was built with for anything the bloc has never
            // fetched, which is exactly this case.
            BlocProvider<DiscoveryBloc>(
              create: (_) => sl<DiscoveryBloc>(),
              child: FullBleedEventCard(
                event: event,
                cardIndex: 0,
                activeCardIndex: _activeCardIndex,
                onTap: () {},
                onHide: () => Navigator.of(context).maybePop(),
              ),
            )
          else if (_loading)
            const Center(child: AppLoadingIndicator())
          else if (_error != null)
            Center(
              child: AppErrorView(
                message: 'Could not open that event.',
                icon: Icons.wifi_off_outlined,
                onRetry: _load,
              ),
            ),

          // A way back, over the media. The feed has the navigation bar for
          // this; a pushed page has nothing, and a full-bleed card leaves no
          // chrome to put a back button in.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 4,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
