import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jperg_app/features/music/presentation/feed_music_controller.dart';
import 'package:jperg_app/core/session/session_reset.dart';
import 'package:jperg_app/features/notifications/data/notification_inbox.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_feed.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_key_datasource.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/ads/data/datasources/feed_comment_data_source.dart';
import 'package:jperg_app/features/ads/presentation/bloc/feed_comment_bloc.dart';
import 'package:jperg_app/features/photo_comments/data/photo_comment_remote_data_source.dart';
import 'package:jperg_app/features/photo_comments/data/picture_like_service.dart';
import 'package:jperg_app/features/photo_comments/presentation/bloc/photo_comment_bloc.dart';
import 'package:jperg_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:jperg_app/features/discovery/data/repositories/discovery_repository_impl.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:jperg_app/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:jperg_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:jperg_app/features/auth/domain/usecases/become_photographer_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/get_token_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/pending_interests_usecases.dart';
import 'package:jperg_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/resend_verification_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/verify_code_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/verify_reset_code_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:jperg_app/features/auth/presentation/bloc/interests/interests_bloc.dart';
import 'package:jperg_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:jperg_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:jperg_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:jperg_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:jperg_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:jperg_app/features/cart/domain/usecases/complete_payment_usecase.dart';
import 'package:jperg_app/features/cart/domain/usecases/download_image_usecase.dart';
import 'package:jperg_app/features/cart/domain/usecases/pay_for_images_usecase.dart';
import 'package:jperg_app/features/cart/domain/usecases/save_images_free_usecase.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';

// ── Chat feature imports ───────────────────────────────────────────────────────
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_media_limits.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:jperg_app/features/chat/data/local/chat_database.dart';
import 'package:jperg_app/features/chat/data/network/chat_api_client.dart';
import 'package:jperg_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jperg_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';

import 'package:jperg_app/features/gallery/data/datasources/found_remote_data_source.dart';
import 'package:jperg_app/features/gallery/data/datasources/gallery_remote_data_source.dart';
import 'package:jperg_app/features/gallery/data/repositories/found_repository_impl.dart';
import 'package:jperg_app/features/gallery/domain/repositories/found_repository.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/bloc/found_bloc.dart';
import 'package:jperg_app/features/gallery/data/datasources/overlay_remote_data_source.dart';
import 'package:jperg_app/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:jperg_app/features/gallery/data/repositories/overlay_repository_impl.dart';
import 'package:jperg_app/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:jperg_app/features/gallery/domain/repositories/overlay_repository.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_gallery_usecase.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_overlay_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:jperg_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:jperg_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:jperg_app/features/home/domain/repositories/home_repository.dart';
import 'package:jperg_app/features/home/domain/usecases/search_events_usecase.dart';
import 'package:jperg_app/features/home/domain/usecases/search_images_usecase.dart';
import 'package:jperg_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:jperg_app/features/search/data/datasources/search_remote_data_source.dart';
import 'package:jperg_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:jperg_app/features/search/domain/repositories/search_repository.dart';
import 'package:jperg_app/features/search/domain/usecases/search_usecase.dart';
import 'package:jperg_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:jperg_app/features/photographers/data/datasources/photographer_remote_data_source.dart';
import 'package:jperg_app/features/photographers/data/repositories/photographer_repository_impl.dart';
import 'package:jperg_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:jperg_app/features/photographers/domain/usecases/get_photographer_events_usecase.dart';
import 'package:jperg_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
import 'package:jperg_app/features/photographers/domain/usecases/photographer_profile_usecases.dart';
import 'package:jperg_app/features/photographers/domain/usecases/get_photographers_usecase.dart';
import 'package:jperg_app/features/photographers/domain/usecases/search_photographers_usecase.dart';
import 'package:jperg_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:jperg_app/features/user_profile/data/datasources/user_profile_local_data_source.dart';
import 'package:jperg_app/features/user_profile/data/datasources/user_profile_remote_data_source.dart';
import 'package:jperg_app/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:jperg_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:jperg_app/features/user_profile/domain/usecases/get_profile_usecase.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/core/theme/theme_cubit.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/services/e2ee_service.dart';
import 'package:jperg_app/services/notification_prefs_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── External ──────────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── Core / Infrastructure ─────────────────────────────────────────────────
  sl.registerSingleton<Api>(Api());

  // ── One-time migration: SharedPreferences → FlutterSecureStorage ──────────
  // Runs on the first launch after upgrading to the secure-storage build.
  // If the old plaintext token exists in SharedPreferences and the new secure
  // store is empty, we copy everything across then wipe SharedPreferences.
  final authService = AuthService();
  final legacyToken = prefs.getString('access_token') ?? '';
  if (legacyToken.isNotEmpty && (await authService.getToken()).isEmpty) {
    await Future.wait([
      authService.setToken(legacyToken),
      if ((prefs.getString('unique_name') ?? '').isNotEmpty)
        authService.setUniqueName(prefs.getString('unique_name')!),
      if ((prefs.getString('id') ?? '').isNotEmpty)
        authService.setId(prefs.getString('id')!),
      if ((prefs.getString('email') ?? '').isNotEmpty)
        authService.setEmail(prefs.getString('email')!),
      if ((prefs.getString('name') ?? '').isNotEmpty)
        authService.setName(prefs.getString('name')!),
    ]);
    for (final key in ['access_token', 'unique_name', 'id', 'email', 'name']) {
      await prefs.remove(key);
    }
  }
  sl.registerSingleton<AuthService>(authService);
  sl.registerSingleton<FeedCacheService>(FeedCacheService(prefs));
  sl.registerSingleton<NotificationPrefsService>(
      NotificationPrefsService(prefs));
  sl.registerSingleton<ThemeCubit>(ThemeCubit(prefs));

  // ── Auth feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<AuthRemoteDataSource>(
      AuthRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      authService: sl<AuthService>(),
    ),
  );
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(
        sl<AuthRepository>(),
        sl<AuthService>(),
        sl<ChatDatabase>(),
        sl<E2eeService>(),
        sl<ChatKeyDataSource>(),
      ));
  sl.registerSingleton<RegisterUseCase>(RegisterUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton<VerifyCodeUseCase>(
      () => VerifyCodeUseCase(sl<AuthRepository>(), sl<LoginUseCase>()));
  sl.registerSingleton<ResendVerificationUseCase>(
      ResendVerificationUseCase(sl<AuthRepository>()));
  sl.registerSingleton<BecomePhotographerUseCase>(
      BecomePhotographerUseCase(sl<AuthRepository>()));
  sl.registerSingleton<GetTokenUseCase>(GetTokenUseCase(sl<AuthRepository>()));
  sl.registerSingleton<LogoutUseCase>(LogoutUseCase(sl<AuthRepository>()));
  sl.registerSingleton<UpdateProfileUseCase>(
      UpdateProfileUseCase(sl<AuthRepository>()));
  sl.registerSingleton<SetPendingInterestsUseCase>(
      SetPendingInterestsUseCase(sl<AuthRepository>()));
  sl.registerSingleton<GetPendingInterestsUseCase>(
      GetPendingInterestsUseCase(sl<AuthRepository>()));
  sl.registerSingleton<ClearPendingInterestsUseCase>(
      ClearPendingInterestsUseCase(sl<AuthRepository>()));
  sl.registerSingleton<RequestPasswordResetUseCase>(
      RequestPasswordResetUseCase(sl<AuthRepository>()));
  sl.registerSingleton<VerifyResetCodeUseCase>(
      VerifyResetCodeUseCase(sl<AuthRepository>()));
  sl.registerSingleton<ResetPasswordUseCase>(
      ResetPasswordUseCase(sl<AuthRepository>()));

  sl.registerFactory<LoginBloc>(() => LoginBloc(
        loginUseCase: sl<LoginUseCase>(),
        getPendingInterests: sl<GetPendingInterestsUseCase>(),
        resendVerification: sl<ResendVerificationUseCase>(),
      ));
  sl.registerFactory<SignUpBloc>(() => SignUpBloc(
        registerUseCase: sl<RegisterUseCase>(),
      ));
  sl.registerFactory<InterestsBloc>(() => InterestsBloc(
        updateProfileUseCase: sl<UpdateProfileUseCase>(),
        clearPendingInterests: sl<ClearPendingInterestsUseCase>(),
        authService: sl<AuthService>(),
      ));

  // ── Home feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<HomeRemoteDataSource>(
      HomeRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<HomeRepository>(
      HomeRepositoryImpl(sl<HomeRemoteDataSource>()));
  sl.registerSingleton<SearchEventsUseCase>(
      SearchEventsUseCase(sl<HomeRepository>()));
  sl.registerSingleton<SearchImagesUseCase>(
      SearchImagesUseCase(sl<HomeRepository>()));

  sl.registerFactory<HomeBloc>(() => HomeBloc(
        searchEventsUseCase: sl<SearchEventsUseCase>(),
        searchImagesUseCase: sl<SearchImagesUseCase>(),
        saveImagesFree: sl<SaveImagesForFreeUseCase>(),
      ));

  // ── Search feature ────────────────────────────────────────────────────────
  // The Search screen (`/client/search/*`) — separate from the Home feature's
  // legacy event search above, which is the web sidebar's typeahead.
  sl.registerSingleton<SearchRemoteDataSource>(
      SearchRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<SearchRepository>(
      SearchRepositoryImpl(sl<SearchRemoteDataSource>()));
  sl.registerSingleton<SearchUseCase>(SearchUseCase(sl<SearchRepository>()));

  sl.registerFactory<SearchBloc>(
      () => SearchBloc(searchUseCase: sl<SearchUseCase>()));

  // ── Discovery feature ─────────────────────────────────────────────────────
  sl.registerSingleton<DiscoveryRemoteDataSource>(
      DiscoveryRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<DiscoveryRepository>(
      DiscoveryRepositoryImpl(sl<DiscoveryRemoteDataSource>()));
  sl.registerSingleton<GetRandomImagesUseCase>(
      GetRandomImagesUseCase(sl<DiscoveryRepository>()));

  sl.registerFactory<DiscoveryBloc>(() => DiscoveryBloc(
        getRandomImagesUseCase: sl<GetRandomImagesUseCase>(),
        getReactionsBatch: sl<GetEventReactionsBatchUseCase>(),
        getEventRoomsBatch: sl<GetEventRoomsBatchUseCase>(),
        feedCache: sl<FeedCacheService>(),
      ));

  // ── Gallery feature ───────────────────────────────────────────────────────
  sl.registerSingleton<GalleryRemoteDataSource>(
      GalleryRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<GalleryRepository>(
      GalleryRepositoryImpl(sl<GalleryRemoteDataSource>()));
  sl.registerSingleton<GetGalleryUseCase>(
      GetGalleryUseCase(sl<GalleryRepository>()));

  sl.registerFactory<GalleryBloc>(
      () => GalleryBloc(getGalleryUseCase: sl<GetGalleryUseCase>()));

  // ── Found feature (face recognitions) ─────────────────────────────────────
  // Separate from Gallery above on purpose: Gallery is the *purchased* photo
  // list (`/client/dashboard`), Found is the recognition list
  // (`/client/my-photos`). They are different tables server-side.
  sl.registerSingleton<FoundRemoteDataSource>(
      FoundRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<FoundRepository>(
      FoundRepositoryImpl(sl<FoundRemoteDataSource>()));
  sl.registerSingleton<GetFoundPhotosUseCase>(
      GetFoundPhotosUseCase(sl<FoundRepository>()));

  sl.registerFactory<FoundBloc>(
      () => FoundBloc(getFoundPhotosUseCase: sl<GetFoundPhotosUseCase>()));

  // Overlay (shared across gallery + event pictures)
  sl.registerSingleton<OverlayRemoteDataSource>(
      OverlayRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<OverlayRepository>(
      OverlayRepositoryImpl(sl<OverlayRemoteDataSource>()));
  sl.registerSingleton<GetOverlayImageUseCase>(
      GetOverlayImageUseCase(sl<OverlayRepository>()));

  // ── Cart feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<CartRemoteDataSource>(
      CartRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<CartRepository>(
      CartRepositoryImpl(sl<CartRemoteDataSource>()));
  sl.registerSingleton<PayForImagesUseCase>(
      PayForImagesUseCase(sl<CartRepository>()));
  sl.registerSingleton<CompletePaymentUseCase>(
      CompletePaymentUseCase(sl<CartRepository>()));
  sl.registerSingleton<DownloadImageUseCase>(
      DownloadImageUseCase(sl<CartRepository>()));
  sl.registerSingleton<SaveImagesForFreeUseCase>(
      SaveImagesForFreeUseCase(sl<CartRepository>()));

  sl.registerSingleton<CartBloc>(CartBloc(
    repository: sl<CartRepository>(),
    downloadImageUseCase: sl<DownloadImageUseCase>(),
  ));

  // ── Photographers feature ─────────────────────────────────────────────────
  sl.registerSingleton<PhotographerRemoteDataSource>(
      PhotographerRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<PhotographerRepository>(
      PhotographerRepositoryImpl(sl<PhotographerRemoteDataSource>()));
  sl.registerSingleton<GetPhotographersUseCase>(
      GetPhotographersUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<SearchPhotographersUseCase>(
      SearchPhotographersUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<GetPhotographerSamplesUseCase>(
      GetPhotographerSamplesUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<UploadSamplesUseCase>(
      UploadSamplesUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<DeleteSampleUseCase>(
      DeleteSampleUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<GetPhotographerEventsUseCase>(
      GetPhotographerEventsUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<GetPhotographerProfileUseCase>(
      GetPhotographerProfileUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<UpdatePhotographerProfileUseCase>(
      UpdatePhotographerProfileUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<UploadPhotographerProfilePhotoUseCase>(
      UploadPhotographerProfilePhotoUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<UploadStudioImageUseCase>(
      UploadStudioImageUseCase(sl<PhotographerRepository>()));
  sl.registerSingleton<SubmitVerificationUseCase>(
      SubmitVerificationUseCase(sl<PhotographerRepository>()));

  sl.registerFactory<PhotographerBloc>(() => PhotographerBloc(
        getPhotographersUseCase: sl<GetPhotographersUseCase>(),
        searchPhotographersUseCase: sl<SearchPhotographersUseCase>(),
      ));

  // ── User Profile feature ──────────────────────────────────────────────────
  sl.registerSingleton<UserProfileLocalDataSource>(
      UserProfileLocalDataSourceImpl(sl<AuthService>()));
  sl.registerSingleton<UserProfileRemoteDataSource>(
      UserProfileRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<UserProfileRepository>(UserProfileRepositoryImpl(
    sl<UserProfileLocalDataSource>(),
    sl<UserProfileRemoteDataSource>(),
    sl<AuthService>(),
  ));
  sl.registerSingleton<GetProfileUseCase>(
      GetProfileUseCase(sl<UserProfileRepository>()));
  sl.registerSingleton<UserLogoutUseCase>(
      UserLogoutUseCase(sl<UserProfileRepository>()));

  sl.registerFactory<UserProfileBloc>(() => UserProfileBloc(
        getProfileUseCase: sl<GetProfileUseCase>(),
        logoutUseCase: sl<UserLogoutUseCase>(),
        notificationPrefsService: sl<NotificationPrefsService>(),
        updateProfileUseCase: sl<UpdateProfileUseCase>(),
        profileRepository: sl<UserProfileRepository>(),
        authService: sl<AuthService>(),
        getFeatures: sl<GetFeaturesUseCase>(),
        setAnonymousMode: sl<SetAnonymousModeUseCase>(),
        setHideProfile: sl<SetHideProfileUseCase>(),
      ));

  // ── Session teardown ──────────────────────────────────────────────────────
  //
  // What a signed-in session leaves lying about outside the widget tree.
  // Registered here, in the one place that already knows the whole app, rather
  // than reached into from `AuthService.removeToken` — core must not import
  // features. Holders with their own lifecycle (ChatRoomsBloc, and anything
  // else built and closed by the tree) register themselves instead.
  //
  // Blocs created per screen need nothing: signing out replaces the navigation
  // stack, which disposes them. It is the ones that outlive it that leak.
  SessionReset.register(
    FeedCacheService,
    'FeedCacheService',
    () => sl<FeedCacheService>().clear(),
  );
  SessionReset.register(
    FollowRepository,
    'FollowRepository.followedIds',
    FollowRepository.clearSession,
  );
  SessionReset.register(
    CartBloc,
    'CartBloc',
    () => sl<CartBloc>().add(const CartCleared()),
  );
  SessionReset.register(
    ChatBackgroundService,
    'ChatBackgroundService',
    // `disconnectAll` was written for exactly this — "Disconnects the global
    // connection (e.g. on logout)" — and nothing ever called it. It drops the
    // socket authenticated as the departing account, which left open goes on
    // delivering their messages into a signed-out app and has the next sign-in
    // open a second one beside it, and it empties the rooms this service holds
    // in memory. Those are what refilled the inbox and the unread badge even
    // once the database beneath them had been cleared.
    () => sl<ChatBackgroundService>().disconnectAll(),
  );
  SessionReset.register(
    ChatDatabase,
    'ChatDatabase',
    // Conversations and messages on disk. Also wiped at *login* when the
    // account differs from the last one on this device — that path stays,
    // because it is the only thing covering a session that ended without a
    // sign-out at all: a crash, an expired token, a reinstall over the top.
    () => sl<ChatDatabase>().clearAll(),
  );
  SessionReset.register(
    NotificationInbox,
    'NotificationInbox',
    // Registered here as well as from its own constructor, because that
    // constructor is a lazy static: an account that never opened the
    // notifications tab never built the inbox, never registered it, and — the
    // part that matters — the *next* account opening that tab builds it for
    // the first time and inherits nothing. Harmless either way, and it stops
    // the guarantee depending on which screens someone happened to visit.
    () => NotificationInbox.instance.clear(),
  );
  SessionReset.register(
    #feedNavigationState,
    'feed navigation notifiers',
    () {
      // Static, so they outlive every screen that reads them: a pending tab
      // request from the old session would be honoured after the new one
      // signed in, and the Found tab's badge kept a count of photos belonging
      // to somebody else.
      FoundFeed.pendingCount.value = 0;
      HomePage.tabRequest.value = null;
      HomePage.webSelectedTab.value = 0;
      HomeNavigationPage.pillTabRequest.value = null;
      HomeNavigationPage.webEventResults.value = const [];
    },
  );

  // ── Feed music ────────────────────────────────────────────────────────────
  // One controller, and therefore one audio player, for every feed in the app.
  // Lazy so no decoder is created for a session that never reaches a scored
  // event — which is most of them.
  sl.registerLazySingleton<FeedMusicController>(() {
    final auth = sl<AuthService>();
    final controller = FeedMusicController(
      persistMuted: auth.setFeedMusicMuted,
    );
    // The stored preference arrives a moment after the controller does. That
    // is soon enough: nothing is playing yet, and restoring it applies to the
    // first card that claims.
    auth.getFeedMusicMuted().then(controller.restoreMuted);
    SessionReset.register(
      FeedMusicController,
      'FeedMusicController',
      controller.endSession,
    );
    return controller;
  });

  // ── Chat feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<ChatApiClient>(ChatApiClient(sl<AuthService>()));
  sl.registerSingleton<ChatDatabase>(ChatDatabase());
  sl.registerSingleton<ChatWebSocketService>(
      ChatWebSocketService(sl<AuthService>()));
  // E2eeService must be registered before ChatBackgroundService (decrypt-on-arrival).
  sl.registerLazySingleton<E2eeService>(() => E2eeService());
  sl.registerSingleton<ChatBackgroundService>(ChatBackgroundService(
      sl<ChatDatabase>(),
      sl<ChatWebSocketService>(),
      sl<E2eeService>(),
      sl<AuthService>(),
      sl<NotificationPrefsService>()));

  sl.registerSingleton<ChatRestDataSource>(
      ChatRestDataSourceImpl(sl<ChatApiClient>()));
  sl.registerSingleton<UserSearchDataSource>(UserSearchDataSource(sl<Api>()));
  sl.registerSingleton<ChatRepository>(
      ChatRepositoryImpl(sl<ChatRestDataSource>(), sl<ChatDatabase>()));

  // Use cases
  sl.registerSingleton<GetGlobalRoomUseCase>(
      GetGlobalRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventRoomUseCase>(
      GetEventRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventRoomsBatchUseCase>(
      GetEventRoomsBatchUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetPhotoRoomUseCase>(
      GetPhotoRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetSampleRoomUseCase>(
      GetSampleRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetOrCreateDirectRoomUseCase>(
      GetOrCreateDirectRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<CanMessageUseCase>(
      CanMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<CreateEventPrivateRoomUseCase>(
      CreateEventPrivateRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetMyRoomsUseCase>(
      GetMyRoomsUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetCachedRoomsUseCase>(
      GetCachedRoomsUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetRoomUseCase>(GetRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<InviteToRoomUseCase>(
      InviteToRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<EditMessageUseCase>(
      EditMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<DeleteMessageUseCase>(
      DeleteMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<PinMessageUseCase>(
      PinMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<UpdateCachedMessageUseCase>(
      UpdateCachedMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<DeleteCachedMessageUseCase>(
      DeleteCachedMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<CreateGroupRoomUseCase>(
      CreateGroupRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<AcceptRoomInviteUseCase>(
      AcceptRoomInviteUseCase(sl<ChatRepository>()));
  sl.registerSingleton<DeclineRoomInviteUseCase>(
      DeclineRoomInviteUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GrantAdminUseCase>(
      GrantAdminUseCase(sl<ChatRepository>()));
  sl.registerSingleton<RevokeAdminUseCase>(
      RevokeAdminUseCase(sl<ChatRepository>()));
  // One instance so the limits are fetched once per session, not per picker.
  sl.registerSingleton<ChatMediaLimitsService>(
      ChatMediaLimitsService(sl<ChatApiClient>()));
  sl.registerSingleton<UpdateRoomSettingsUseCase>(
      UpdateRoomSettingsUseCase(sl<ChatRepository>()));
  sl.registerSingleton<SetRoomMutedUseCase>(
      SetRoomMutedUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetRoomMediaUseCase>(
      GetRoomMediaUseCase(sl<ChatRepository>()));
  sl.registerSingleton<KickParticipantUseCase>(
      KickParticipantUseCase(sl<ChatRepository>()));
  sl.registerSingleton<LeaveRoomUseCase>(
      LeaveRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<DeleteRoomUseCase>(
      DeleteRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<ClearRoomCacheUseCase>(
      ClearRoomCacheUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetRoomMessagesUseCase>(
      GetRoomMessagesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetCachedMessagesUseCase>(
      GetCachedMessagesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<CacheMessageUseCase>(
      CacheMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetUnreadCountsUseCase>(
      GetUnreadCountsUseCase(sl<ChatRepository>(), sl<AuthService>()));
  sl.registerSingleton<GetLastMessageTimesUseCase>(
      GetLastMessageTimesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<MarkRoomAsReadUseCase>(
      MarkRoomAsReadUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetPresenceUseCase>(
      GetPresenceUseCase(sl<ChatRepository>()));
  sl.registerSingleton<UploadChatImageUseCase>(
      UploadChatImageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventReactionUseCase>(
      GetEventReactionUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventReactionsBatchUseCase>(
      GetEventReactionsBatchUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetFeaturesUseCase>(
      GetFeaturesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<SetAnonymousModeUseCase>(
      SetAnonymousModeUseCase(sl<ChatRepository>()));
  sl.registerSingleton<SetHideProfileUseCase>(
      SetHideProfileUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetBlockedUsersUseCase>(
      GetBlockedUsersUseCase(sl<ChatRepository>()));
  sl.registerSingleton<BlockUserUseCase>(
      BlockUserUseCase(sl<ChatRepository>()));
  sl.registerSingleton<UnblockUserUseCase>(
      UnblockUserUseCase(sl<ChatRepository>()));

  sl.registerSingleton<ChatKeyDataSource>(ChatKeyDataSource(sl<Api>()));

  // Saved items
  sl.registerSingleton<ClientSavedDataSource>(
      ClientSavedDataSource(sl<Api>(), sl<AuthService>()));
  // Singleton on purpose: the bookmark state has to be the same object for
  // every rail, or saving in one viewer leaves the other showing unsaved.
  sl.registerSingleton<SavedPhotos>(
      SavedPhotos(ApiSavedPhotoStore(sl<ClientSavedDataSource>())));

  // BLoCs (factories so each page gets a fresh instance)
  sl.registerFactory<ChatRoomsBloc>(() => ChatRoomsBloc(
        getMyRooms: sl<GetMyRoomsUseCase>(),
        getCachedRooms: sl<GetCachedRoomsUseCase>(),
        getUnreadCounts: sl<GetUnreadCountsUseCase>(),
        getLastMessageTimes: sl<GetLastMessageTimesUseCase>(),
        getRoomMessages: sl<GetRoomMessagesUseCase>(),
        acceptInvite: sl<AcceptRoomInviteUseCase>(),
        declineInvite: sl<DeclineRoomInviteUseCase>(),
        clearRoomCache: sl<ClearRoomCacheUseCase>(),
        bgService: sl<ChatBackgroundService>(),
        authService: sl<AuthService>(),
      ));

  sl.registerFactory<ChatRoomBloc>(() => ChatRoomBloc(
        keyDataSource: sl<ChatKeyDataSource>(),
        e2eeService: sl<E2eeService>(),
        getRoomMessages: sl<GetRoomMessagesUseCase>(),
        getRoom: sl<GetRoomUseCase>(),
        getCachedMessages: sl<GetCachedMessagesUseCase>(),
        cacheMessage: sl<CacheMessageUseCase>(),
        markRoomAsRead: sl<MarkRoomAsReadUseCase>(),
        getPresence: sl<GetPresenceUseCase>(),
        uploadImage: sl<UploadChatImageUseCase>(),
        editMessage: sl<EditMessageUseCase>(),
        deleteMessage: sl<DeleteMessageUseCase>(),
        pinMessage: sl<PinMessageUseCase>(),
        updateCachedMessage: sl<UpdateCachedMessageUseCase>(),
        deleteCachedMessage: sl<DeleteCachedMessageUseCase>(),
        grantAdmin: sl<GrantAdminUseCase>(),
        revokeAdmin: sl<RevokeAdminUseCase>(),
        updateRoomSettings: sl<UpdateRoomSettingsUseCase>(),
        setRoomMuted: sl<SetRoomMutedUseCase>(),
        kickParticipant: sl<KickParticipantUseCase>(),
        leaveRoom: sl<LeaveRoomUseCase>(),
        deleteRoom: sl<DeleteRoomUseCase>(),
        clearRoomCache: sl<ClearRoomCacheUseCase>(),
        authService: sl<AuthService>(),
        bgService: sl<ChatBackgroundService>(),
      ));

  // ── Photo Comments feature ────────────────────────────────────────────────
  sl.registerSingleton<PhotoCommentRemoteDataSource>(
      PhotoCommentRemoteDataSourceImpl(sl<Api>()));
  sl.registerFactory<PhotoCommentBloc>(() =>
      PhotoCommentBloc(sl<PhotoCommentRemoteDataSource>(), sl<AuthService>()));
  sl.registerSingleton<PictureLikeService>(
      PictureLikeService(sl<ChatRestDataSource>()));

  // ── Feed Comments (ads / requests) ───────────────────────────────────────
  sl.registerSingleton<FeedCommentDataSource>(
      FeedCommentDataSourceImpl(sl<Api>()));
  sl.registerFactory<FeedCommentBloc>(
      () => FeedCommentBloc(sl<FeedCommentDataSource>(), sl<AuthService>()));

  // ── Super admin app config ────────────────────────────────────────────────
  sl.registerSingleton<AppConfigRepository>(AppConfigRepository(sl<Api>()));
}
