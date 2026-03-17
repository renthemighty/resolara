import 'dart:io';
import 'dart:ui';

/// Collects device and screen metadata for server-side prompt optimisation.
/// The server uses this to tailor image composition and label sizing
/// to the requesting screen without requiring an app update.
class DeviceInfoService {
  static Map<String, dynamic> collect() {
    final view = PlatformDispatcher.instance.views.first;
    final physicalSize = view.physicalSize;
    final pixelRatio = view.devicePixelRatio;

    final logicalWidth  = physicalSize.width  / pixelRatio;
    final logicalHeight = physicalSize.height / pixelRatio;

    final isTablet = logicalWidth >= 600 || logicalHeight >= 600;
    final isLandscape = logicalWidth > logicalHeight;

    return {
      'platform':      Platform.isIOS ? 'iOS' : 'Android',
      'device_type':   isTablet ? 'tablet' : 'phone',
      'screen_width':  logicalWidth.round(),
      'screen_height': logicalHeight.round(),
      'pixel_ratio':   double.parse(pixelRatio.toStringAsFixed(2)),
      'orientation':   isLandscape ? 'landscape' : 'portrait',
      'os_version':    Platform.operatingSystemVersion,
    };
  }
}
