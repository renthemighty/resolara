import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: Resolara()));
}

class Resolara extends StatelessWidget {
  const Resolara({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Resolara',
      theme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
