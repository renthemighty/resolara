// Platform dispatcher — picks the correct entry point at compile time.
//
// On native (iOS/Android), `dart.library.js_interop` is not available, so
// `mobile_entry.dart` is loaded and its main() runs the full mobile app.
// When Flutter Web compiles this file, `dart.library.js_interop` resolves
// and `web_entry.dart` is loaded instead — which only boots the clinic
// PWA and never touches Drift, path_provider, Firebase, or camera plugins.

import 'app/platform_entry/mobile_entry.dart'
    if (dart.library.js_interop) 'app/platform_entry/web_entry.dart' as entry;

Future<void> main() => entry.main();
