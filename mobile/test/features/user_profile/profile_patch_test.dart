/// What a profile edit actually sends.
///
/// The bug this pins: saving the form failed even when nothing about the
/// username had been touched. The handle is the one field the API validates as
/// a format — `[A-Za-z0-9_]{3,30}` — and the app used to prefill it from
/// `uiqueName`, the face-recognition person id, which for every account that
/// did not sign up as a photographer is their **email address**. So the form
/// submitted an address to that field and the server refused it, which made
/// changing a phone number impossible and said nothing about why.
///
/// An untouched field is not an edit. Nothing to validate, nothing to send.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';

ProfileUpdateSubmitted _edit({
  String name = 'Sara Johnson',
  String uniqueName = 'sarajohnson4821',
  String contact = '',
  String countryCode = '',
  String locale = '',
  String preferredLanguage = '',
  String timezone = '',
  List<String> interestTags = const [],
}) =>
    ProfileUpdateSubmitted(
      name: name,
      uniqueName: uniqueName,
      contact: contact,
      countryCode: countryCode,
      locale: locale,
      preferredLanguage: preferredLanguage,
      timezone: timezone,
      interestTags: interestTags,
    );

void main() {
  group('whether the handle was edited', () {
    test('unchanged is not an edit', () {
      expect(
        handleWasEdited(_edit(uniqueName: 'sarajohnson4821'), 'sarajohnson4821'),
        isFalse,
      );
    });

    test('a different handle is', () {
      expect(handleWasEdited(_edit(uniqueName: 'sara_j'), 'sarajohnson4821'),
          isTrue);
    });

    test('an empty field is not an edit either', () {
      // Clearing the box is not a request to be nameless — the API has no way
      // to express that, and "" would fail its minimum length anyway.
      expect(handleWasEdited(_edit(uniqueName: ''), 'sarajohnson4821'), isFalse);
    });
  });

  group('the patch body', () {
    test('leaves the handle out when it was not touched', () {
      final patch = profilePatchFor(
        _edit(uniqueName: 'sarajohnson4821', contact: '0551234567'),
        currentHandle: 'sarajohnson4821',
      );

      expect(patch.containsKey('username'), isFalse);
      expect(patch['contact'], '0551234567');
    });

    test('a stale email in the field cannot block the rest of the save', () {
      // Exactly the broken state: a build that cached `uiqueName` as the
      // handle, so the form is prefilled with an address nobody typed. The
      // phone number still has to save.
      final patch = profilePatchFor(
        _edit(uniqueName: 'sara@example.com', contact: '0551234567'),
        currentHandle: 'sara@example.com',
      );

      expect(patch.containsKey('username'), isFalse);
      expect(patch['contact'], '0551234567');
    });

    test('sends the handle when it really changed', () {
      final patch = profilePatchFor(
        _edit(uniqueName: 'sara_j'),
        currentHandle: 'sarajohnson4821',
      );
      expect(patch['username'], 'sara_j');
    });

    test('empty fields are absent, not blanked', () {
      // The endpoint treats every field as optional and absent as "leave it
      // alone"; "" would mean "clear it".
      final patch = profilePatchFor(
        _edit(name: '', uniqueName: '', contact: ''),
        currentHandle: 'sarajohnson4821',
      );
      expect(patch, isEmpty);
    });

    test('uses the API field names, not the app ones', () {
      final patch = profilePatchFor(
        _edit(
          countryCode: 'GH',
          locale: 'en_GB',
          preferredLanguage: 'en',
          timezone: 'Africa/Accra',
          interestTags: const ['wedding'],
        ),
        currentHandle: 'sarajohnson4821',
      );

      expect(patch['country_code'], 'GH');
      expect(patch['preferred_language'], 'en');
      expect(patch['interest_tags'], ['wedding']);
      expect(patch['locale'], 'en_GB');
      expect(patch['timezone'], 'Africa/Accra');
      // `uiqueName` is the face-recognition person id and must never be a key
      // here: writing it would orphan the account's enrolled face.
      expect(patch.containsKey('uiqueName'), isFalse);
    });
  });
}
