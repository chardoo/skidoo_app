import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/verification/data/verification_api.dart';
import 'package:jperg_app/features/verification/presentation/verification_form.dart';

/// Verifying a creator, by typed details rather than a photograph of the card.
///
/// The thing this most has to get right is that it never asks for an image.
/// Ghana's NIA and Data Protection Commission both treat storing one as
/// something a private company may not casually do, and the upload that used
/// to be here is the reason this file exists.
///
/// After that: the documents offered follow the country, a rejection says why,
/// and an approved account is not invited to submit again.
class _FakeApi implements VerificationApi {
  _FakeApi({
    this.types = const [
      IdDocumentType(
          value: 'ghana_card', label: 'Ghana Card', hint: 'GHA-123456789-0'),
      IdDocumentType(value: 'passport', label: 'Passport', hint: 'G1234567'),
    ],
    this.current,
    this.refusal,
  });

  final List<IdDocumentType> types;
  VerificationStatus? current;
  String? refusal;
  final submissions = <Map<String, Object?>>[];

  @override
  Future<List<IdDocumentType>> documentTypes({String? country}) async => types;

  @override
  Future<VerificationStatus?> status() async => current;

  @override
  Future<String?> submit({
    required String legalName,
    required String idType,
    required String idNumber,
    required DateTime dateOfBirth,
    String? countryCode,
    ({bool payoutPolicy, bool terms, bool uploadRights}) agreements =
        const (terms: true, uploadRights: true, payoutPolicy: true),
  }) async {
    submissions.add({
      'legalName': legalName,
      'idType': idType,
      'idNumber': idNumber,
      'dob': dateOfBirth,
      'terms': agreements.terms,
    });
    if (refusal == null) {
      current = const VerificationStatus(status: 'pending');
    }
    return refusal;
  }
}

void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  Future<void> open(WidgetTester t, _FakeApi api,
      {Widget? extra, bool canSubmit = true}) async {
    await t.pumpWidget(host(
      VerificationForm(api: api, extra: extra, canSubmit: canSubmit),
    ));
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, {String number = 'GHA-123456789-0'}) async {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Kwame Mensah');
    await t.enterText(fields.at(1), number);
    // The date picker, which is the only way to give a date of birth.
    await t.tap(find.text('Date of birth'));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
  }

  group('it never asks for the card itself', () {
    testWidgets('there is nothing to upload', (t) async {
      await open(t, _FakeApi());

      // No control that takes a file, and no image on screen. Asserted on the
      // widgets rather than on words: the reassurance below deliberately says
      // "photo", so matching text would catch the promise instead of a breach
      // of it.
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.camera_alt_rounded), findsNothing);
      expect(find.byIcon(Icons.upload_rounded), findsNothing);
      expect(find.textContaining('Upload'), findsNothing);
    });

    testWidgets('and it says so', (t) async {
      // The thing people expect to be asked for and are relieved not to be.
      await open(t, _FakeApi());

      expect(find.text('We never ask for a photo of your card.'), findsOneWidget);
    });
  });

  group('the documents offered', () {
    testWidgets('come from the server, not from here', (t) async {
      // A form that says "National ID" to somebody in Accra is a form written
      // by somebody who has not been there.
      await open(t, _FakeApi());

      expect(find.text('Ghana Card'), findsOneWidget);
    });

    testWidgets('the hint shows what the number looks like', (t) async {
      // The difference between typing your number and guessing the format.
      await open(t, _FakeApi());

      expect(find.text('GHA-123456789-0'), findsOneWidget);
    });
  });

  group('submitting', () {
    testWidgets('sends what was typed', (t) async {
      final api = _FakeApi();
      await open(t, api);

      await fill(t);
      await t.tap(find.text('Submit for verification'));
      await t.pumpAndSettle();

      expect(api.submissions.length, 1);
      expect(api.submissions.single['legalName'], 'Kwame Mensah');
      expect(api.submissions.single['idType'], 'ghana_card');
      expect(api.submissions.single['idNumber'], 'GHA-123456789-0');
    });

    testWidgets('a missing name is caught before the network', (t) async {
      final api = _FakeApi();
      await open(t, api);

      await t.tap(find.text('Submit for verification'));
      await t.pumpAndSettle();

      expect(api.submissions, isEmpty);
    });

    testWidgets("the server's own complaint is what is shown", (t) async {
      // Only the server knows *which* field was wrong, and "that does not look
      // like a valid number for that document" is worth putting in front of
      // somebody in a way "something went wrong" is not.
      final api = _FakeApi(refusal: 'That does not look like a valid number');
      await open(t, api);

      await fill(t, number: 'NOPE');
      await t.tap(find.text('Submit for verification'));
      await t.pumpAndSettle();

      expect(find.text('That does not look like a valid number'), findsOneWidget);
    });

    testWidgets('it lands as pending, not as verified', (t) async {
      // Submitting is a claim. The badge is somebody having checked it.
      final api = _FakeApi();
      await open(t, api);

      await fill(t);
      await t.tap(find.text('Submit for verification'));
      await t.pumpAndSettle();

      expect(find.text('Waiting on review'), findsOneWidget);
    });
  });

  group('where it already stands', () {
    testWidgets('an approved account is not asked again', (t) async {
      // Re-submitting cannot un-verify anybody, and offering the form only
      // invites somebody to try.
      await open(t, _FakeApi(current: const VerificationStatus(status: 'approved')));

      expect(find.text('Verified'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a rejection says why', (t) async {
      // A rejection without a reason leaves somebody guessing which of four
      // fields was wrong.
      await open(t, _FakeApi(
        current: const VerificationStatus(
          status: 'rejected',
          rejectionReason: 'The number did not match the name',
        ),
      ));

      expect(find.text('The number did not match the name'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('a rejected attempt keeps the name it had', (t) async {
      // So somebody fixes one field rather than typing all four again.
      await open(t, _FakeApi(
        current: const VerificationStatus(
          status: 'rejected',
          legalName: 'Kwame Mensah',
        ),
      ));

      expect(find.text('Kwame Mensah'), findsOneWidget);
    });
  });

  group('the creator wizard', () {
    testWidgets('its consent boxes ride along', (t) async {
      await open(t, _FakeApi(), extra: const Text('I agree to the terms'));

      expect(find.text('I agree to the terms'), findsOneWidget);
    });

    testWidgets('and hold the button closed until ticked', (t) async {
      // The agreements are a legal record. Submitting without them is the one
      // thing the wizard must not allow.
      final api = _FakeApi();
      await open(t, api, canSubmit: false);

      await fill(t);
      await t.tap(find.text('Submit for verification'));
      await t.pumpAndSettle();

      expect(api.submissions, isEmpty);
    });
  });
}
