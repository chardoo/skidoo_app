// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:firebase_analytics/observer.dart';
// import 'package:firetest/core/constants/environment.dart';
// import 'package:firetest/generated/l10n.dart';
// import 'package:firetest/routes/router.dart';
// import 'package:firetest/services/config_service.dart';
// import 'package:firetest/services/general_service.dart';
// import 'package:get/get.dart';
// import 'package:flutter/material.dart';
// import 'package:meta/meta.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';

// class MyAndroidApp extends StatelessWidget {
//   final ConfigService configService;
//   final FirebaseAnalytics analytics;
//   final GeneralService generalService;
//   const MyAndroidApp({
//     Key key,
//     @required this.configService,
//     @required this.analytics,
//     @required this.generalService,
//   })  : assert(
//           configService != null,
//         ),
//         super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Obx(() => GetMaterialApp(
//           enableLog:
//               this.configService.configModel.environment == Environment.dev,
//           defaultTransition: Transition.native,
//           opaqueRoute: Get.isOpaqueRouteDefault,
//           popGesture: Get.isPopGestureEnable,
//           theme: ThemeData(
//             visualDensity: VisualDensity.adaptivePlatformDensity,
//           ),
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
//           navigatorKey: Get.key,
//           initialRoute: Routes.SPLASH_ROUTE,
//           getPages: AppPages.appPages,
//           navigatorObservers: [
//             GetObserver(),
//             FirebaseAnalyticsObserver(analytics: this.analytics),
//           ],
//         ));
//   }
// }
