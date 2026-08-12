import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Answers to the questions this app actually gets asked, and a way to reach a
/// person when the answer is not here.
///
/// Deliberately shipped in the app rather than fetched: it has to work for
/// somebody whose problem is that nothing loads, which is when a help screen
/// earns its place.
const _faqs = <(String, String)>[
  (
    'How do I find photos of me?',
    'Add your face once in Settings › Privacy › Manage Face Data. After that, '
        'photos of you are found automatically as photographers upload them, '
        'and appear in the Found tab. You can also scan an event QR code to '
        'search a single event straight away.',
  ),
  (
    'Why can I not see a photo I was told about?',
    'Private photos are only shown to the people in them and to the '
        'photographer. If you were recognised in one it appears in your Found '
        'tab; if the photographer has since made it private or removed it, it '
        'stops appearing.',
  ),
  (
    'How do I buy a photo?',
    'Open the photo and press Buy. Choose as many as you like, then pay once '
        'for all of them. Free photos are saved to your gallery without '
        'payment.',
  ),
  (
    'I paid and my photos are not in my gallery.',
    'Payments settle a moment after the card clears. If they have not appeared '
        'after a minute, reopen the app — and if they are still missing, '
        'contact us with the date and amount and we will find the payment.',
  ),
  (
    'How do I stop being recognised?',
    'Settings › Privacy › Allow Face Recognition. Turning it off deletes your '
        'face data and stops photos of you being found. Photos already found '
        'stay in your list.',
  ),
  (
    'How do I become a photographer?',
    'Settings › Account & Security › Become a Creator. You can then create '
        'events, upload photos and set your own prices.',
  ),
];

/// Where "Contact us" goes. A mailbox rather than a chat room: support here is
/// answered by people reading mail, and a chat that nobody is watching is
/// worse than an address that is.
const _supportEmail = 'support@jperg.com';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _readVersion();
  }

  Future<void> _readVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Not worth a message. The screen is useful without it.
    }
  }

  Future<void> _contact() async {
    // The version rides along in the subject: it is the first thing support
    // asks for and the last thing anyone can find.
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Jperg support${_version.isEmpty ? '' : ' — app $_version'}',
      },
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        AppSnackBar.error(context, 'Write to us at $_supportEmail');
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'Write to us at $_supportEmail');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Help & Support',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h,
            AppSpacing.lg.w, AppSpacing.xxxl.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: 'Common questions',
                  children: [
                    for (final (question, answer) in _faqs)
                      _Faq(question: question, answer: answer, ext: ext),
                  ],
                ),
                SettingsSection(
                  title: 'Still stuck',
                  children: [
                    SettingsRow(
                      label: 'Contact us',
                      subtitle: _supportEmail,
                      onTap: _contact,
                    ),
                  ],
                ),
                if (_version.isNotEmpty)
                  Center(
                    child: Text(
                      'Jperg $_version',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

/// One question, opening onto its answer. Collapsed by default so the list
/// reads as a list of questions rather than a wall of text.
class _Faq extends StatelessWidget {
  const _Faq({
    required this.question,
    required this.answer,
    required this.ext,
  });

  final String question;
  final String answer;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // The default divider on an ExpansionTile draws its own lines on top of
      // the section's hairlines.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg.r)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg.r)),
        tilePadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        childrenPadding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.md.h),
        iconColor: ext.searchHintColor,
        collapsedIconColor: ext.searchHintColor,
        title: Text(
          question,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
