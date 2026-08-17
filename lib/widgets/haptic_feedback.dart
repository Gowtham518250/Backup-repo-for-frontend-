import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

/// Haptic Feedback Helper
/// Provides haptic feedback for key interactions
class HapticFeedbackHelper {
  /// Light haptic feedback for subtle interactions
  static Future<void> light() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 50, amplitude: 64);
        }
      });
    } catch (_) {}
  }

  /// Medium haptic feedback for standard interactions
  static Future<void> medium() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 100, amplitude: 128);
        }
      });
    } catch (_) {}
  }

  /// Heavy haptic feedback for important actions
  static Future<void> heavy() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 200, amplitude: 255);
        }
      });
    } catch (_) {}
  }

  /// Success haptic feedback pattern
  static Future<void> success() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(pattern: [0, 50, 50, 50]);
        }
      });
    } catch (_) {}
  }

  /// Error haptic feedback pattern
  static Future<void> error() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(pattern: [0, 100, 50, 100]);
        }
      });
    } catch (_) {}
  }

  /// Warning haptic feedback pattern
  static Future<void> warning() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(pattern: [0, 75]);
        }
      });
    } catch (_) {}
  }

  /// Selection haptic feedback
  static Future<void> selection() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 25, amplitude: 48);
        }
      });
    } catch (_) {}
  }

  /// Impact haptic feedback for button presses
  static Future<void> impact() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 30, amplitude: 80);
        }
      });
    } catch (_) {}
  }

  /// Notification haptic feedback
  static Future<void> notification() async {
    try {
      await Vibration.hasVibrator().then((hasVibrator) async {
        if (hasVibrator == true) {
          await Vibration.vibrate(pattern: [0, 100, 50, 200]);
        }
      });
    } catch (_) {}
  }
}

/// Haptic Button Wrapper
/// Automatically provides haptic feedback on button press
class HapticButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final HapticType hapticType;

  const HapticButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.hapticType = HapticType.medium,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _triggerHaptic(),
      onTap: onPressed,
      child: child,
    );
  }

  void _triggerHaptic() {
    switch (hapticType) {
      case HapticType.light:
        HapticFeedbackHelper.light();
        break;
      case HapticType.medium:
        HapticFeedbackHelper.medium();
        break;
      case HapticType.heavy:
        HapticFeedbackHelper.heavy();
        break;
      case HapticType.success:
        HapticFeedbackHelper.success();
        break;
      case HapticType.error:
        HapticFeedbackHelper.error();
        break;
      case HapticType.warning:
        HapticFeedbackHelper.warning();
        break;
      case HapticType.selection:
        HapticFeedbackHelper.selection();
        break;
      case HapticType.impact:
        HapticFeedbackHelper.impact();
        break;
    }
  }
}

/// Haptic Type Enum
enum HapticType {
  light,
  medium,
  heavy,
  success,
  error,
  warning,
  selection,
  impact,
}

/// Haptic ListTile
/// ListTile with automatic haptic feedback
class HapticListTile extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;
  final HapticType hapticType;
  final Widget? trailing;

  const HapticListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.hapticType = HapticType.selection,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return HapticButton(
      onPressed: onTap,
      hapticType: hapticType,
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
