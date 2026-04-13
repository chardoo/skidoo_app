import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/photographer_card.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/photographers_header.dart';

class PhotographersPage extends StatefulWidget {
  const PhotographersPage({super.key});

  @override
  State<PhotographersPage> createState() => _PhotographersPageState();
}

class _PhotographersPageState extends State<PhotographersPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  late final TextEditingController _textCtrl;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _textCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearchOpen = true);
    _ctrl.forward();
  }

  void _closeSearch() {
    setState(() => _isSearchOpen = false);
    _ctrl.reverse();
    _textCtrl.clear();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    context.read<PhotographerBloc>().add(const PhotographersLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          PhotographersHeader(
            progress: _progress,
            textCtrl: _textCtrl,
            isSearchOpen: _isSearchOpen,
            onSearchOpen: _openSearch,
            onSearchClose: _closeSearch,
            onSearchChanged: (q) {
              context
                  .read<PhotographerBloc>()
                  .add(PhotographersSearched(q));
            },
          ),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<PhotographerBloc, PhotographerState>(
              builder: (context, state) {
                if (state.isLoading) return const AppLoadingIndicator();
                if (state.errorMessage != null) {
                  return AppErrorView(
                    message: state.errorMessage!,
                    onRetry: () => context
                        .read<PhotographerBloc>()
                        .add(const PhotographersLoadRequested()),
                  );
                }
                if (state.photographers.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.person_search_rounded,
                    message: 'No creators found.',
                  );
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView.builder(
                      padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
                      itemCount: state.photographers.length,
                      itemBuilder: (context, index) {
                        final p = state.photographers[index];
                        return PhotographerCard(
                          photographer: p,
                          onTap: () {
                            final homeBloc = context.read<HomeBloc>();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: homeBloc,
                                child: PhotographerProfilePage(photographer: p),
                              ),
                            ));
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}
