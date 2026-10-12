import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/app_store.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/shell.dart';

class AracTakipApp extends StatelessWidget {
  const AracTakipApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      // Hesap silinince / çıkış yapılınca bütün ekranlar sıfırdan kurulur.
      child: ValueListenableBuilder<int>(
        valueListenable: store.session,
        builder: (context, session, _) => MaterialApp(
        key: ValueKey(session),
        title: 'Tekerim',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Büyük yazı ayarı açık olsa da ekranlar taşmasın (en fazla 1,3 kat).
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
            ),
            child: child!,
          );
        },
        home: const _Root(),
      ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.settings.onboarded) return const WelcomeScreen();
    return const Shell();
  }
}
