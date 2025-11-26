import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_providers.dart';
import 'services/language_preference_service.dart';
import 'splash_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: AppProviders.allProviders.cast(),
          child: Selector<LanguagePreferenceService, String>(
            selector: (context, lang) => lang.currentLanguage,
            builder: (context, currentLanguageCode, _) {
              final locale = Locale(currentLanguageCode);
              final textDirection = currentLanguageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr; // French is LTR like English

              return MaterialApp(
                title: 'Sahla',
                theme: ThemeData(
                  primarySwatch: Colors.blue,
                  scaffoldBackgroundColor:
                      Colors.white, // Ensure white background
                  // PERFORMANCE FIX: Set colorScheme to ensure proper background color immediately
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blue,
                    brightness: Brightness.light,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                      systemNavigationBarColor: Colors.white,
                      systemNavigationBarIconBrightness: Brightness.dark,
                    ),
                  ),
                ),
                darkTheme: ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: Colors.black,
                  // PERFORMANCE FIX: Set colorScheme to ensure proper background color immediately
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blue,
                    brightness: Brightness.dark,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.black,
                    elevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                      systemNavigationBarColor: Colors.white,
                      systemNavigationBarIconBrightness: Brightness.dark,
                    ),
                  ),
                ),
                // Note: SplashScreen has its own orange background, so theme mode doesn't affect it
                themeMode: ThemeMode.system,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) {
                  // Wrap with AnnotatedRegion to ensure white navigation bar across all screens
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                      systemNavigationBarColor: Colors.white,
                      systemNavigationBarIconBrightness: Brightness.dark,
                    ),
                    child: Directionality(
                      textDirection: textDirection,
                      child: child!,
                    ),
                  );
                },
                onGenerateRoute: AppRouter.onGenerateRoute,
                onUnknownRoute: AppRouter.onUnknownRoute,
                home: const SplashScreen(),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        );
      },
    );
  }
}
