// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:firebase_analytics/observer.dart';
// import 'package:firetest/core/constants/environment.dart';
// import 'package:firetest/generated/l10n.dart';
// import 'package:firetest/routes/router.dart';
// import 'package:firetest/services/config_service.dart';
// import 'package:firetest/services/general_service.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:get/get.dart';
// import 'package:meta/meta.dart';

// class MyIOSApp extends StatelessWidget {
//   final ConfigService configService;
//   final FirebaseAnalytics analytics;
//   final GeneralService generalService;

//   const MyIOSApp({
//     Key key,
//     @required this.configService,
//     @required this.analytics,
//     @required this.generalService,
//   })  : assert(
//           configService != null,
//           analytics != null,
//         ),
//         super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Obx(() => GetCupertinoApp(
//           enableLog:
//               this.configService.configModel.environment == Environment.dev,
//           defaultTransition: Transition.native,
//           opaqueRoute: Get.isOpaqueRouteDefault,
//           popGesture: Get.isPopGestureEnable,
//           navigatorKey: Get.key,
//           theme: CupertinoThemeData(),
//           initialRoute: Routes.SPLASH_ROUTE,
//           localizationsDelegates: [
//             LangTranslator.delegate,
//             GlobalMaterialLocalizations.delegate,
//             GlobalWidgetsLocalizations.delegate,
//             GlobalCupertinoLocalizations.delegate
//           ],
//           locale: this.generalService.currentLocale.value,
//           supportedLocales: LangTranslator.delegate.supportedLocales,
//           fallbackLocale: LangTranslator.delegate.supportedLocales.first,
//           localeResolutionCallback:
//               (Locale locale, Iterable<Locale> supportedLocales) {
//             for (var supportedLocale in supportedLocales) {
//               if (supportedLocale.languageCode == locale.languageCode) {
//                 return locale;
//               }
//             }
//             return supportedLocales.first;
//           },
//           getPages: AppPages.appPages,
//           navigatorObservers: [
//             GetObserver(),
//             FirebaseAnalyticsObserver(analytics: this.analytics)
//           ],
//         ));
//   }
// }
