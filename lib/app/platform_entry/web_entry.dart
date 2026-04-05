// Web entry point — Flutter Web PWA for clinic platform.
// Selected by conditional import in main.dart when dart.library.js_interop is
// available (i.e. compiling to JavaScript/WASM). Deliberately does not touch
// Firebase, path_provider, Drift, camera or any mobile-only package.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platforms/web/clinic_web_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ClinicWebApp()));
}
