import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_discovery_card.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

// ── Scrollable events feed (authenticated) ────────────────────────────────────

class EventsFeed extends StatefulWidget {
  const EventsFeed({
    super.key,
    required this.discoveryState,
    required this.onCardTap,
    required this.onCommentTap,
    required this.onLoadMore,
  });

  final DiscoveryState discoveryState;
  final ValueChanged<EventDiscovery> onCardTap;
  final ValueChanged<EventDiscovery> onCommentTap;
  final VoidCallback onLoadMore;

  @override
  State<EventsFeed> createState() => _EventsFeedState();
}

class _EventsFeedState extends State<EventsFeed> {
  /// Which card index (in the feed list) should have its video playing.
  final _activeCardIndex = ValueNotifier<int>(0);

  /// Stable GlobalKey per event id — reused across rebuilds so RenderBox
  /// lookups stay valid after list updates.
  final _cardKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String eventId) =>
      _cardKeys.putIfAbsent(eventId, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    // Measure once after the first frame so card 0 auto-plays on load.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateActiveCard());
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    super.dispose();
  }

  /// Find the card whose centre is closest to the viewport centre and mark it
  /// as active so its video starts playing (others pause).
  void _updateActiveCard() {
    if (!mounted) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final viewportMid = screenH / 2;
    final events = widget.discoveryState.events;

    int? bestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < events.length; i++) {
      final key = _cardKeys[events[i].id];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      final cardCenter = pos.dy + box.size.height / 2;
      final dist = (cardCenter - viewportMid).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    if (bestIdx != null && bestIdx != _activeCardIndex.value) {
      _activeCardIndex.value = bestIdx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.discoveryState;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 300) {
            widget.onLoadMore();
          }
          // Update the active card every scroll tick.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateActiveCard());
        } else if (notification is ScrollEndNotification) {
          // Final snap after fling.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateActiveCard());
        }
        return false;
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: state.events.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.events.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: const AppLoadingIndicator(),
                );
              }
              final event = state.events[index];
              return EventDiscoveryCard(
                key: _keyFor(event.id),
                event: event,
                cardIndex: index,
                activeCardIndex: _activeCardIndex,
                isAuthenticated: true,
                onTap: () => widget.onCardTap(event),
                onCommentTap: () => widget.onCommentTap(event),
              );
            },
          ),
        ),
      ),
    );
  }
}
