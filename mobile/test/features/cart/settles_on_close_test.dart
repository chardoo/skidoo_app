import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:jperg_app/features/cart/domain/usecases/download_image_usecase.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/features/gallery/data/purchased_photos.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Settling a basket when the checkout closes, however it closed.
///
/// `PAYSTACK_CALLBACK_URL` is unset on this deployment, so a finished payment
/// very often ends on a page with no redirect left in it. "They paid and were
/// never sent back" and "they changed their mind" therefore look identical from
/// the app, and the only thing that can tell them apart is the server:
/// `/client/payments/complete-images` verifies the reference with Paystack
/// before it settles anything, and is idempotent.
///
/// So the basket is settled either way. What differs is whether a refusal is
/// said out loud — see `CartPaymentCompleted.quiet`.
///
/// Only the calls these tests make are stubbed below; anything else reaching a
/// stub is a mistake in the test rather than a method worth writing.
mixin _Unused {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName} is not used here');
}

class _Repo with _Unused implements CartRepository {
  _Repo({this.settles = true, this.throws = false});

  /// Whether the server hands photos over.
  final bool settles;

  /// Whether it refuses outright, as it does for an unpaid reference.
  final bool throws;

  int completeCalls = 0;

  @override
  Future<Map<String, dynamic>> completeImages({
    required String referenceId,
    required String clientId,
    required List<Map<String, String>> pictures,
  }) async {
    completeCalls++;
    if (throws) throw ServerException('Payment verification failed');
    return {
      'paidImages': {'count': settles ? pictures.length : 0}
    };
  }

}

class _Auth with _Unused implements AuthService {
  @override
  Future<String> getUserId() async => 'buyer-1';
}

class _Store implements PurchasedPhotoStore {
  @override
  Future<List<String>> purchasedIds() async => const [];
}

Photo photo(String id) => Photo.fromMap({
      'id': id,
      'url': 'https://cdn/$id.jpg',
      'price': 20,
      'event': const {'id': 'evt-1', 'eventName': 'Praise', 'userId': 'pg-1'},
    });

CartBloc blocWith(_Repo repo) {
  if (GetIt.I.isRegistered<AuthService>()) GetIt.I.unregister<AuthService>();
  GetIt.I.registerSingleton<AuthService>(_Auth());
  return CartBloc(
    repository: repo,
    downloadImageUseCase: DownloadImageUseCase(repo),
  )..add(CartItemsReplaced([photo('pic-1')]));
}

void main() {
  setUp(() {
    if (!GetIt.I.isRegistered<PurchasedPhotos>()) {
      GetIt.I.registerSingleton<PurchasedPhotos>(PurchasedPhotos(_Store()));
    }
  });

  tearDown(GetIt.I.reset);

  test('a payment that cleared is settled even though nobody was redirected',
      () async {
    final repo = _Repo();
    final bloc = blocWith(repo);
    addTearDown(bloc.close);
    await Future<void>.delayed(Duration.zero);

    // quiet: true is the buyer closing the screen — which on this deployment
    // is also how a finished payment ends.
    bloc.add(const CartPaymentCompleted(quiet: true));
    await bloc.stream.firstWhere((s) => s.status == CartStatus.paymentSuccess);

    expect(repo.completeCalls, 1, reason: 'the server has to be asked');
    expect(bloc.state.items, isEmpty);
    expect(purchasedPhotosOrNull()!.isPurchased('pic-1'), isTrue,
        reason: 'the Buy tag must come off the photo behind the checkout');
  });

  test('a buyer who changed their mind is not told a payment failed', () async {
    final repo = _Repo(throws: true);
    final bloc = blocWith(repo);
    addTearDown(bloc.close);
    await Future<void>.delayed(Duration.zero);

    bloc.add(const CartPaymentCompleted(quiet: true));
    final state =
        await bloc.stream.firstWhere((s) => s.status != CartStatus.paymentLoading);

    expect(state.status, CartStatus.paymentAbandoned);
    expect(state.errorMessage, isNull);
    // The basket survives, so pressing Buy again does not start from nothing.
    expect(state.items, hasLength(1));
  });

  test('a refusal after a real redirect does speak up', () async {
    final repo = _Repo(throws: true);
    final bloc = blocWith(repo);
    addTearDown(bloc.close);
    await Future<void>.delayed(Duration.zero);

    // quiet: false is a redirect that carried a reference.
    bloc.add(const CartPaymentCompleted());
    final state =
        await bloc.stream.firstWhere((s) => s.status != CartStatus.paymentLoading);

    expect(state.status, CartStatus.paymentFailure);
    expect(state.errorMessage, isNotNull);
  });

  test('settling twice is harmless — the channels overlap', () async {
    // The checkout watches three channels and more than one fires for the same
    // redirect; the screen guards against it, and the endpoint is idempotent
    // besides. This pins the half the bloc owns: the second settle finds an
    // empty basket and does not claim a second success.
    final repo = _Repo();
    final bloc = blocWith(repo);
    addTearDown(bloc.close);
    await Future<void>.delayed(Duration.zero);

    bloc.add(const CartPaymentCompleted());
    await bloc.stream.firstWhere((s) => s.status == CartStatus.paymentSuccess);
    expect(bloc.state.items, isEmpty);
  });
}
