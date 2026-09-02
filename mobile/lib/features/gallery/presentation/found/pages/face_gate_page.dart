import 'package:flutter/material.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';
import 'package:jperg_app/services/auth_service.dart';

/// "Add your face to get found", as a screen in front of an action that needs
/// a face.
///
/// The Found tab renders [FaceGatePrompt] as its own empty state — it has a
/// whole tab to fill and nothing to put in it. Scanning is different: the
/// action is a tap on the feed bar, and without this it opened the code sheet
/// to somebody whose scan could not match anything, because face matching has
/// no reference selfie to match against. The failure arrived later and
/// elsewhere, as an event that simply held no photos of them.
///
/// Pops true once the user is through the gate, so the caller can carry on
/// into the thing they originally tapped rather than dropping it — the same
/// "detour, not a dead end" rule the sign-up prompts in [found_access] follow.
class FaceGatePage extends StatefulWidget {
  const FaceGatePage({super.key});

  /// Shows the gate and resolves true if the user came out of it able to
  /// proceed.
  static Future<bool> show(BuildContext context) async {
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const FaceGatePage()),
    );
    return passed ?? false;
  }

  @override
  State<FaceGatePage> createState() => _FaceGatePageState();
}

class _FaceGatePageState extends State<FaceGatePage> {
  FoundAccess? _access;

  @override
  void initState() {
    super.initState();
    _resolve();
    // A face can be added from elsewhere while this sits on the stack — the
    // capture screen this pushes is the ordinary case, but settings can do it
    // too. Listening means the gate opens itself rather than stranding someone
    // on a screen asking for something they have already done.
    AuthService.hasAddedFaces.addListener(_resolve);
  }

  @override
  void dispose() {
    AuthService.hasAddedFaces.removeListener(_resolve);
    super.dispose();
  }

  Future<void> _resolve() async {
    final access = await resolveFoundAccess();
    if (!mounted) return;
    if (access == FoundAccess.ready) {
      // Nothing left to ask for. Straight back to whatever they tapped.
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _access = access);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final access = _access;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const AppBackButton(),
      ),
      // Blank rather than a spinner while the first resolve runs: it reads
      // local auth state and returns within a frame or two, and a spinner that
      // brief is a flash, not information.
      body: access == null
          ? const SizedBox.shrink()
          : FaceGatePrompt(
              // No copy overrides. This is the Found tab's gate, shown in
              // front of a scan instead of in place of a feed — the reason a
              // face is needed is the same one, so wording it differently here
              // would be two explanations of one rule, drifting apart.
              reason: access == FoundAccess.signedOut
                  ? FaceGateReason.signedOut
                  : FaceGateReason.noFaceAdded,
              onPrimaryAction: () async {
                if (access == FoundAccess.signedOut) {
                  await promptSignUp(
                    context,
                    onAuthenticated: () async {
                      if (!mounted) return;
                      // Sign-up runs its own face step; only follow up when it
                      // was skipped, or this is a second capture.
                      if (!AuthService.hasAddedFaces.value) {
                        await startFaceCapture(context);
                      }
                    },
                  );
                } else {
                  await startFaceCapture(context);
                }
                await _resolve();
              },
              onSignIn: access == FoundAccess.signedOut
                  ? () => openSignIn(context, onAuthenticated: _resolve)
                  : null,
            ),
    );
  }
}
