import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:skidoo_app/features/discovery/data/repositories/discovery_repository_impl.dart';
import 'package:skidoo_app/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:skidoo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:skidoo_app/features/auth/domain/usecases/get_token_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/register_usecase.dart';
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
import 'package:skidoo_app/services/notification_prefs_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── External ──────────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── Core / Infrastructure ─────────────────────────────────────────────────
  sl.registerSingleton<Api>(Api());
  sl.registerSingleton<AuthService>(AuthService());
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
  sl.registerSingleton<LoginUseCase>(LoginUseCase(sl<AuthRepository>()));
  sl.registerSingleton<RegisterUseCase>(RegisterUseCase(sl<AuthRepository>()));
  sl.registerSingleton<GetTokenUseCase>(GetTokenUseCase(sl<AuthRepository>()));
  sl.registerSingleton<LogoutUseCase>(LogoutUseCase(sl<AuthRepository>()));

  sl.registerFactory<LoginBloc>(
      () => LoginBloc(loginUseCase: sl<LoginUseCase>()));
  sl.registerFactory<SignUpBloc>(
      () => SignUpBloc(registerUseCase: sl<RegisterUseCase>()));

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
      ));

  // ── Chat feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<ChatApiClient>(ChatApiClient(sl<AuthService>()));
  sl.registerSingleton<ChatDatabase>(ChatDatabase());
  sl.registerSingleton<ChatBackgroundService>(
      ChatBackgroundService(sl<AuthService>(), sl<ChatDatabase>()));

  sl.registerSingleton<ChatRestDataSource>(
      ChatRestDataSourceImpl(sl<ChatApiClient>()));
  sl.registerSingleton<ChatRepository>(
      ChatRepositoryImpl(sl<ChatRestDataSource>(), sl<ChatDatabase>()));

  // Use cases
  sl.registerSingleton<GetGlobalRoomUseCase>(
      GetGlobalRoomUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventRoomUseCase>(
      GetEventRoomUseCase(sl<ChatRepository>()));
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
  sl.registerSingleton<GetRoomMessagesUseCase>(
      GetRoomMessagesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetCachedMessagesUseCase>(
      GetCachedMessagesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<CacheMessageUseCase>(
      CacheMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetUnreadCountsUseCase>(
      GetUnreadCountsUseCase(sl<ChatRepository>(), sl<AuthService>()));
  sl.registerSingleton<MarkRoomAsReadUseCase>(
      MarkRoomAsReadUseCase(sl<ChatRepository>()));
  sl.registerSingleton<UploadChatImageUseCase>(
      UploadChatImageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetEventReactionUseCase>(
      GetEventReactionUseCase(sl<ChatRepository>()));

  // BLoCs (factories so each page gets a fresh instance)
  sl.registerFactory<ChatRoomsBloc>(() => ChatRoomsBloc(
        getMyRooms: sl<GetMyRoomsUseCase>(),
        getCachedRooms: sl<GetCachedRoomsUseCase>(),
        getUnreadCounts: sl<GetUnreadCountsUseCase>(),
        getRoomMessages: sl<GetRoomMessagesUseCase>(),
        bgService: sl<ChatBackgroundService>(),
      ));

  sl.registerFactory<ChatRoomBloc>(() => ChatRoomBloc(
        getRoomMessages: sl<GetRoomMessagesUseCase>(),
        getCachedMessages: sl<GetCachedMessagesUseCase>(),
        cacheMessage: sl<CacheMessageUseCase>(),
        markRoomAsRead: sl<MarkRoomAsReadUseCase>(),
        uploadImage: sl<UploadChatImageUseCase>(),
        wsService: ChatWebSocketService(sl<AuthService>()),
        authService: sl<AuthService>(),
        bgService: sl<ChatBackgroundService>(),
      ));
}
