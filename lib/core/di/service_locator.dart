import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_key_datasource.dart';
import 'package:skidoo_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/features/ads/data/datasources/feed_comment_data_source.dart';
import 'package:skidoo_app/features/ads/presentation/bloc/feed_comment_bloc.dart';
import 'package:skidoo_app/features/photo_comments/data/photo_comment_remote_data_source.dart';
import 'package:skidoo_app/features/photo_comments/data/picture_like_service.dart';
import 'package:skidoo_app/features/photo_comments/presentation/bloc/photo_comment_bloc.dart';
import 'package:skidoo_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:skidoo_app/features/discovery/data/repositories/discovery_repository_impl.dart';
import 'package:skidoo_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:skidoo_app/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:skidoo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:skidoo_app/features/auth/domain/usecases/get_token_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/pending_interests_usecases.dart';
import 'package:skidoo_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/interests/interests_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:skidoo_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:skidoo_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:skidoo_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:skidoo_app/features/cart/domain/usecases/complete_payment_usecase.dart';
import 'package:skidoo_app/features/cart/domain/usecases/download_image_usecase.dart';
import 'package:skidoo_app/features/cart/domain/usecases/pay_for_images_usecase.dart';
import 'package:skidoo_app/features/cart/domain/usecases/save_images_free_usecase.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';

// ── Chat feature imports ───────────────────────────────────────────────────────
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:skidoo_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/features/chat/data/network/chat_api_client.dart';
import 'package:skidoo_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';

import 'package:skidoo_app/features/gallery/data/datasources/gallery_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/data/datasources/overlay_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:skidoo_app/features/gallery/data/repositories/overlay_repository_impl.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/overlay_repository.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_gallery_usecase.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_overlay_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:skidoo_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:skidoo_app/features/home/domain/repositories/home_repository.dart';
import 'package:skidoo_app/features/home/domain/usecases/search_events_usecase.dart';
import 'package:skidoo_app/features/home/domain/usecases/search_images_usecase.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/photographers/data/datasources/photographer_remote_data_source.dart';
import 'package:skidoo_app/features/photographers/data/repositories/photographer_repository_impl.dart';
import 'package:skidoo_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographer_events_usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographers_usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/search_photographers_usecase.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/user_profile/data/datasources/user_profile_local_data_source.dart';
import 'package:skidoo_app/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:skidoo_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:skidoo_app/features/user_profile/domain/usecases/get_profile_usecase.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/core/theme/theme_cubit.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/services/e2ee_service.dart';
import 'package:skidoo_app/services/notification_prefs_service.dart';

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

  sl.registerFactory<LoginBloc>(() => LoginBloc(
        loginUseCase: sl<LoginUseCase>(),
        getPendingInterests: sl<GetPendingInterestsUseCase>(),
      ));
  sl.registerFactory<SignUpBloc>(() => SignUpBloc(
        registerUseCase: sl<RegisterUseCase>(),
        setPendingInterests: sl<SetPendingInterestsUseCase>(),
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

  // ── Discovery feature ─────────────────────────────────────────────────────
  sl.registerSingleton<DiscoveryRemoteDataSource>(
      DiscoveryRemoteDataSourceImpl(sl<Api>()));
  sl.registerSingleton<DiscoveryRepository>(
      DiscoveryRepositoryImpl(sl<DiscoveryRemoteDataSource>()));
  sl.registerSingleton<GetRandomImagesUseCase>(
      GetRandomImagesUseCase(sl<DiscoveryRepository>()));

  sl.registerFactory<DiscoveryBloc>(() => DiscoveryBloc(
        getRandomImagesUseCase: sl<GetRandomImagesUseCase>(),
        getEventReaction: sl<GetEventReactionUseCase>(),
        getEventRoom: sl<GetEventRoomUseCase>(),
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
    payForImagesUseCase: sl<PayForImagesUseCase>(),
    completePaymentUseCase: sl<CompletePaymentUseCase>(),
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

  sl.registerFactory<PhotographerBloc>(() => PhotographerBloc(
        getPhotographersUseCase: sl<GetPhotographersUseCase>(),
        searchPhotographersUseCase: sl<SearchPhotographersUseCase>(),
      ));

  // ── User Profile feature ──────────────────────────────────────────────────
  sl.registerSingleton<UserProfileLocalDataSource>(
      UserProfileLocalDataSourceImpl(sl<AuthService>()));
  sl.registerSingleton<UserProfileRepository>(
      UserProfileRepositoryImpl(sl<UserProfileLocalDataSource>()));
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

  // ── Chat feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<ChatApiClient>(ChatApiClient(sl<AuthService>()));
  sl.registerSingleton<ChatDatabase>(ChatDatabase());
  sl.registerSingleton<ChatWebSocketService>(ChatWebSocketService(sl<AuthService>()));
  // E2eeService must be registered before ChatBackgroundService (decrypt-on-arrival).
  sl.registerLazySingleton<E2eeService>(() => E2eeService());
  sl.registerSingleton<ChatBackgroundService>(
      ChatBackgroundService(sl<ChatDatabase>(), sl<ChatWebSocketService>(),
          sl<E2eeService>(), sl<AuthService>()));

  sl.registerSingleton<ChatRestDataSource>(
      ChatRestDataSourceImpl(sl<ChatApiClient>()));
  sl.registerSingleton<UserSearchDataSource>(
      UserSearchDataSource(sl<Api>()));
  sl.registerSingleton<ChatRepository>(
      ChatRepositoryImpl(sl<ChatRestDataSource>(), sl<ChatDatabase>()));

  // Use cases
  sl.registerSingleton<GetGlobalRoomUseCase>(
      GetGlobalRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventRoomUseCase>(
      GetEventRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetPhotoRoomUseCase>(
      GetPhotoRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetSampleRoomUseCase>(
      GetSampleRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetOrCreateDirectRoomUseCase>(
      GetOrCreateDirectRoomUseCase(sl<ChatRepository>()));
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
  sl.registerSingleton<UpdateRoomSettingsUseCase>(
      UpdateRoomSettingsUseCase(sl<ChatRepository>()));
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
  sl.registerSingleton<UploadChatImageUseCase>(
      UploadChatImageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventReactionUseCase>(
      GetEventReactionUseCase(sl<ChatRepository>()));
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

  // BLoCs (factories so each page gets a fresh instance)
  sl.registerFactory<ChatRoomsBloc>(() => ChatRoomsBloc(
        getMyRooms: sl<GetMyRoomsUseCase>(),
        getCachedRooms: sl<GetCachedRoomsUseCase>(),
        getUnreadCounts: sl<GetUnreadCountsUseCase>(),
        getLastMessageTimes: sl<GetLastMessageTimesUseCase>(),
        getRoomMessages: sl<GetRoomMessagesUseCase>(),
        acceptInvite: sl<AcceptRoomInviteUseCase>(),
        declineInvite: sl<DeclineRoomInviteUseCase>(),
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
        uploadImage: sl<UploadChatImageUseCase>(),
        editMessage: sl<EditMessageUseCase>(),
        deleteMessage: sl<DeleteMessageUseCase>(),
        updateCachedMessage: sl<UpdateCachedMessageUseCase>(),
        deleteCachedMessage: sl<DeleteCachedMessageUseCase>(),
        grantAdmin: sl<GrantAdminUseCase>(),
        revokeAdmin: sl<RevokeAdminUseCase>(),
        updateRoomSettings: sl<UpdateRoomSettingsUseCase>(),
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
  sl.registerFactory<PhotoCommentBloc>(
      () => PhotoCommentBloc(sl<PhotoCommentRemoteDataSource>(), sl<AuthService>()));
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
