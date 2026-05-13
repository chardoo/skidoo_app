import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';

const _eventTypes = [
  'Wedding', 'Birthday', 'Corporate', 'Concert',
  'Graduation', 'Engagement', 'Baby Shower', 'Other',
];

class RequestBoardPage extends StatefulWidget {
  const RequestBoardPage({super.key});

  @override
  State<RequestBoardPage> createState() => _RequestBoardPageState();
}

class _RequestBoardPageState extends State<RequestBoardPage> {
  final _repo = AdsRepository();
  final _locationCtrl = TextEditingController();

  List<FeedRequestModel> _requests = [];
  bool _loading = true;
  String? _errorMessage;
  String? _selectedEventType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    debugPrint('[RequestBoardPage] _load eventType=$_selectedEventType location="${_locationCtrl.text.trim()}"');
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final requests = await _repo.getRequests(
        eventType: _selectedEventType,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
      );
      if (!mounted) return;
      debugPrint('[RequestBoardPage] _load done — ${requests.length} requests');
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[RequestBoardPage] _load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load requests.';
        _loading = false;
      });
    }
  }

  Future<void> _openChat(FeedRequestModel req) async {
    debugPrint('[RequestBoardPage] _openChat requesterId=${req.requesterId} name="${req.requesterName}"');
    final role = req.requesterType == 'photographer'
        ? ChatConfig.rolePhotographer
        : ChatConfig.roleClient;
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: req.requesterId,
        recipientRole: role,
        localDisplayName: req.requesterName,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      debugPrint('[RequestBoardPage] _openChat ERROR: $e');
      if (!mounted) return;
      final blocked = e is ServerException && e.message.contains('400');
      AppSnackBar.error(
        context,
        blocked ? 'This user is not accepting messages.' : 'Could not open chat.',
      );
    }
  }

  void _showFilterSheet() {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        ext: ext,
        selectedEventType: _selectedEventType,
        locationCtrl: _locationCtrl,
        onApply: (eventType) {
          setState(() => _selectedEventType = eventType);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasFilters =
        _selectedEventType != null || _locationCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: ext.greetingColor, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Request Board',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilters,
              backgroundColor: ext.accentGold,
              child: Icon(Icons.tune_rounded,
                  color: ext.greetingColor, size: 22.sp),
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : _errorMessage != null
              ? AppErrorView(
                  message: _errorMessage!,
                  icon: Icons.cloud_off_outlined,
                  onRetry: _load,
                )
              : _requests.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.inbox_outlined,
                      message: 'No open requests found',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: ext.accentGold,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) => FeedItemCard(
                          data: FeedItemData.fromRequest(
                            _requests[i],
                            onMessageTap: () => _openChat(_requests[i]),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.ext,
    required this.selectedEventType,
    required this.locationCtrl,
    required this.onApply,
  });

  final AppThemeExtension ext;
  final String? selectedEventType;
  final TextEditingController locationCtrl;
  final ValueChanged<String?> onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _eventType;

  @override
  void initState() {
    super.initState();
    _eventType = widget.selectedEventType;
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                'Filter Requests',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 20.h),

              Text(
                'Event type',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _eventType == null,
                    ext: ext,
                    onTap: () => setState(() => _eventType = null),
                  ),
                  ..._eventTypes.map((t) => _FilterChip(
                        label: t,
                        selected: _eventType == t,
                        ext: ext,
                        onTap: () => setState(() => _eventType = t),
                      )),
                ],
              ),

              SizedBox(height: 20.h),
              Text(
                'Location',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: widget.locationCtrl,
                style:
                    TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'e.g. Accra',
                  hintStyle: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp),
                  filled: true,
                  fillColor: ext.searchFieldFill,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 13.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                        color: ext.accentGold.withValues(alpha: 0.6),
                        width: 1.2),
                  ),
                ),
              ),

              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onApply(_eventType);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ext.accentGold, const Color(0xFFFF6B35)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected
              ? ext.accentGold.withValues(alpha: 0.15)
              : ext.searchFieldFill,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected
                ? ext.accentGold.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? ext.accentGold : ext.searchHintColor,
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
