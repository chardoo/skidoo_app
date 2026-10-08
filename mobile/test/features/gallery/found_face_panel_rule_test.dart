/// When the Found tab asks for a face instead of sitting empty.
///
/// The original tab answered "no face on file" with an "Add your face to get
/// found" panel for everybody who lacked one — including people who had photos
/// already, because it refused to even fetch the list without an enrolment.
/// That panel was deleted; the rule now turns on what is actually on screen,
/// and most of what is asserted here is the states that must *not* ask.
///
/// For a while the same condition raised the code sheet by itself over a
/// screen reading "Scanning for your face", which for somebody with no face
/// was false in every clause. The condition is unchanged — these assertions
/// carried over intact — but what it now decides is which of two empty states
/// to draw. The sheet is still how a code is entered; it is opened by the
/// panel's button rather than by the screen appearing.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_empty_state.dart';

void main() {
  bool offer(FoundAccess access, FoundEmptyState empty) =>
      shouldOfferFacePanel(access: access, empty: empty);

  group('it is offered', () {
    test('to someone signed in, unenrolled, with nothing found', () {
      expect(
        offer(FoundAccess.noFaceAdded, FoundEmptyState.scanning),
        isTrue,
      );
    });
  });

  group('it is not offered', () {
    test('when photos have already been found', () {
      // The case that matters most, and the one the old gate got wrong: the
      // face was deleted, the identifications were not, and the tab still has
      // their photos. They came to look at them, not to scan something.
      expect(offer(FoundAccess.noFaceAdded, FoundEmptyState.none), isFalse);
    });

    test('when matches are waiting to be reviewed', () {
      // An answer, not an absence — and the review banner is the thing that
      // belongs on screen.
      expect(
        offer(FoundAccess.noFaceAdded, FoundEmptyState.awaitingReview),
        isFalse,
      );
    });

    test('when the filters hid everything', () {
      // The tab is empty because they narrowed it, and the fix is to clear the
      // chips. Asking for a face would answer a question nobody asked.
      expect(
        offer(FoundAccess.noFaceAdded, FoundEmptyState.filteredOut),
        isFalse,
      );
    });

    test('to someone enrolled with no matches yet', () {
      // The system is working for them, and FoundScanningState says so.
      // Asking again for a face they have already given is nagging.
      expect(offer(FoundAccess.ready, FoundEmptyState.scanning), isFalse);
    });

    test('to a guest', () {
      // Easy search reads who you are from the token, so a guest scanning a
      // code would be answered with a 401. Sign-up is the only thing to
      // offer, and FoundJoinPrompt is what offers it.
      expect(offer(FoundAccess.signedOut, FoundEmptyState.scanning), isFalse);
    });

    test('to an enrolled user in any other empty state', () {
      for (final empty in FoundEmptyState.values) {
        expect(
          offer(FoundAccess.ready, empty),
          isFalse,
          reason: 'enrolled users are never asked for a face ($empty)',
        );
      }
    });
  });
}
