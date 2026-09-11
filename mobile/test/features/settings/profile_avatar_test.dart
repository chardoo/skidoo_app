import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Why an account with a profile picture was drawn as its initial.
///
/// `auth.profile_url` had exactly one writer — the upload in Edit Profile — so
/// storage knew a face only if this install had just set one. A fresh sign-in
/// left it empty, and the two places that drew it made that permanent in
/// different ways:
///
///   * the feed's top bar read it once into a Future at build time, and the
///     top bar is built early and kept, so it never asked again;
///   * Settings never passed an image at all — it handed [UserAvatar] an
///     initial and nothing else, so it drew initials for everybody.
///
/// The endpoint had been returning `profile_url` on every profile fetch the
/// whole time. The app dropped it in `_normalise` before anything downstream
/// could see it.
///
/// So: the fetch keeps the field, the bloc mirrors it into [AuthService], and
/// the URL lives in a notifier — the same shape [AuthService.role] already
/// uses, and for the same reason.
void main() {
  group('the profile state carries a picture', () {
    test('it defaults to empty rather than null', () {
      // Callers do `isEmpty ? null : url`, so an absent picture has to be a
      // string they can ask about, not a null they have to guard.
      expect(const UserProfileState().profileUrl, '');
    });

    test('copyWith carries it, and leaves it alone when not named', () {
      const url = 'https://cdn.example.com/me.jpg';
      final withPhoto = const UserProfileState().copyWith(profileUrl: url);
      expect(withPhoto.profileUrl, url);

      // Every other field on this state is updated by name, so a copyWith for
      // some unrelated toggle must not blank the face.
      final later = withPhoto.copyWith(name: 'Joe');
      expect(later.profileUrl, url,
          reason: 'an unrelated copyWith dropped the avatar');
    });

    test('it takes part in equality', () {
      // Equatable decides whether the bloc emits. Left out of props, a profile
      // whose only change was the picture would be judged identical to the one
      // before it and never reach the screen.
      const a = UserProfileState(profileUrl: 'https://cdn.example.com/a.jpg');
      const b = UserProfileState(profileUrl: 'https://cdn.example.com/b.jpg');
      expect(a, isNot(equals(b)));
    });
  });

  group('AuthService.profileUrl is watched, not read once', () {
    setUp(() => AuthService.profileUrl.value = '');

    test('it starts empty', () {
      expect(AuthService.profileUrl.value, '');
    });

    test('setting it notifies, which is the whole point', () {
      // The top bar had no way to hear about a picture that arrived after it
      // was built. This is that way.
      var heard = 0;
      void listener() => heard++;
      AuthService.profileUrl.addListener(listener);
      addTearDown(() => AuthService.profileUrl.removeListener(listener));

      AuthService.profileUrl.value = 'https://cdn.example.com/me.jpg';

      expect(heard, 1);
      expect(AuthService.profileUrl.value, 'https://cdn.example.com/me.jpg');
    });

    test('clearing it notifies too', () {
      // Sign-out sets this back to empty. If that were silent, the last
      // person's face would stay on screen for whoever signed in next.
      AuthService.profileUrl.value = 'https://cdn.example.com/me.jpg';

      var heard = 0;
      void listener() => heard++;
      AuthService.profileUrl.addListener(listener);
      addTearDown(() => AuthService.profileUrl.removeListener(listener));

      AuthService.profileUrl.value = '';

      expect(heard, 1);
      expect(AuthService.profileUrl.value, '');
    });
  });
}
