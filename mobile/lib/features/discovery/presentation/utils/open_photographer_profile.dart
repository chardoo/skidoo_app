import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:jperg_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:jperg_app/models/photographer/photographerModel.dart';

/// Opens a photographer's profile page. Shared by every creator avatar/pin
/// across the discovery feed (classic card, full-bleed card, and the
/// fullscreen picture viewer) so the navigation + optional-HomeBloc-carry
/// logic lives in one place instead of being copied into each card.
void openPhotographerProfile(
  BuildContext context, {
  required String photographerId,
  required String photographerName,
  String? photographerProfileUrl,
}) {
  if (photographerId.isEmpty) return;
  final photographer = PhotographerModel(
    photographerId,
    '',
    photographerName,
    '',
    imageUrl: photographerProfileUrl,
  );
  // HomeBloc may not be in the tree on the unauthenticated discovery page.
  HomeBloc? homeBloc;
  try {
    homeBloc = context.read<HomeBloc>();
  } catch (_) {}

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => homeBloc != null
          ? BlocProvider.value(
              value: homeBloc,
              child: PhotographerProfilePage(photographer: photographer),
            )
          : PhotographerProfilePage(photographer: photographer),
    ),
  );
}
