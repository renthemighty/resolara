import 'package:flutter/foundation.dart';

/// True when ReviewScreen is active on the navigator stack.
final reviewModeNotifier = ValueNotifier<bool>(false);

/// Set by ReviewScreen to open the findings sheet when Details tab is tapped.
VoidCallback? onDetailsTabTapped;
