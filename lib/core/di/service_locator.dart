import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/API/DioClietService.dart';
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
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:skidoo_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:skidoo_app/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:skidoo_app/features/gallery/data/datasources/gallery_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_gallery_usecase.dart';
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
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographers_usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/search_photographers_usecase.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/user_profile/data/datasources/user_profile_local_data_source.dart';
import 'package:skidoo_app/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:skidoo_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:skidoo_app/features/user_profile/domain/usecases/get_profile_usecase.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/services/auth_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── External ──────────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── Core / Infrastructure ─────────────────────────────────────────────────
  sl.registerSingleton<Api>(Api());
  sl.registerSingleton<AuthService>(AuthService());

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

  // Cart is a singleton bloc (shared across screens for persistent cart state)
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
      ));

  // ── Chat feature ──────────────────────────────────────────────────────────
  sl.registerSingleton<ChatRemoteDataSource>(ChatRemoteDataSourceImpl());
  sl.registerSingleton<ChatRepository>(
      ChatRepositoryImpl(sl<ChatRemoteDataSource>()));
  sl.registerSingleton<GetMessagesUseCase>(
      GetMessagesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<GetMoreMessagesUseCase>(
      GetMoreMessagesUseCase(sl<ChatRepository>()));
  sl.registerSingleton<SendMessageUseCase>(
      SendMessageUseCase(sl<ChatRepository>()));
  sl.registerSingleton<UpdateMessageUseCase>(
      UpdateMessageUseCase(sl<ChatRepository>()));

  sl.registerFactory<ChatBloc>(() => ChatBloc(
        getMessagesUseCase: sl<GetMessagesUseCase>(),
        getMoreMessagesUseCase: sl<GetMoreMessagesUseCase>(),
        sendMessageUseCase: sl<SendMessageUseCase>(),
        updateMessageUseCase: sl<UpdateMessageUseCase>(),
      ));
}
