import 'package:flutter/material.dart';
import 'comprehensive_logger.dart';

/// Tracking-aware button widget that automatically logs button clicks
class TrackingAwareButton extends StatelessWidget {
  final String label;
  final String screen;
  final VoidCallback onPressed;
  final Widget? child;
  final ButtonStyle? style;
  final Map<String, dynamic>? context;

  const TrackingAwareButton({
    super.key,
    required this.label,
    required this.screen,
    required this.onPressed,
    this.child,
    this.style,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: () {
        // Log button click
        ComprehensiveLogger.logButtonClick(
          buttonLabel: label,
          screen: screen,
          context: this.context,
        );
        onPressed();
      },
      child: child ?? Text(label),
    );
  }
}

/// Tracking-aware text button widget
class TrackingAwareTextButton extends StatelessWidget {
  final String label;
  final String screen;
  final VoidCallback onPressed;
  final Widget? child;
  final Map<String, dynamic>? context;

  const TrackingAwareTextButton({
    super.key,
    required this.label,
    required this.screen,
    required this.onPressed,
    this.child,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        // Log button click
        ComprehensiveLogger.logButtonClick(
          buttonLabel: label,
          screen: screen,
          context: this.context,
        );
        onPressed();
      },
      child: child ?? Text(label),
    );
  }
}

/// Tracking-aware icon button widget
class TrackingAwareIconButton extends StatelessWidget {
  final String label;
  final String screen;
  final VoidCallback onPressed;
  final Widget icon;
  final Map<String, dynamic>? context;

  const TrackingAwareIconButton({
    super.key,
    required this.label,
    required this.screen,
    required this.onPressed,
    required this.icon,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      onPressed: () {
        // Log button click
        ComprehensiveLogger.logButtonClick(
          buttonLabel: label,
          screen: screen,
          context: this.context,
        );
        onPressed();
      },
    );
  }
}

/// Tracking-aware form widget that automatically logs form submissions
class TrackingAwareForm extends StatefulWidget {
  final String formName;
  final String screen;
  final Widget child;
  final Future<bool> Function()? onSubmit;
  final Map<String, dynamic>? Function()? getFormData;

  const TrackingAwareForm({
    super.key,
    required this.formName,
    required this.screen,
    required this.child,
    this.onSubmit,
    this.getFormData,
  });

  @override
  State<TrackingAwareForm> createState() => _TrackingAwareFormState();
}

class _TrackingAwareFormState extends State<TrackingAwareForm> {
  bool _isSubmitting = false;

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      // Get form data if available
      final formData = widget.getFormData?.call();
      
      // Call submit handler if provided
      bool success = true;
      if (widget.onSubmit != null) {
        success = await widget.onSubmit!();
      }

      // Log form submission
      ComprehensiveLogger.logFormSubmission(
        formName: widget.formName,
        screen: widget.screen,
        success: success,
        formData: formData,
      );
    } catch (e) {
      // Log form submission failure
      ComprehensiveLogger.logFormSubmission(
        formName: widget.formName,
        screen: widget.screen,
        success: false,
        error: e.toString(),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: widget.child,
    );
  }
}

/// Mixin for automatic user action tracking in widgets
mixin UserActionTracking<T extends StatefulWidget> on State<T> {
  String get screenName => 'UnknownScreen';

  void logUserAction(String action, [Map<String, dynamic>? details]) {
    ComprehensiveLogger.logUserAction(
      action: action,
      screen: screenName,
      details: details,
    );
  }

  void logScreenView([Map<String, dynamic>? details]) {
    logUserAction('screen_view', details);
  }

  void logFeatureUse(String feature, [Map<String, dynamic>? details]) {
    logUserAction('feature_use', {...?details, 'feature': feature});
  }

  void logError(String error, [Map<String, dynamic>? context]) {
    ComprehensiveLogger.logError(
      location: screenName,
      message: error,
      data: context,
    );
  }
}

/// Helper class for wrapping existing widgets with tracking
class WidgetTracker {
  /// Wrap a widget with screen name context for tracking
  static Widget withScreenContext({
    required Widget child,
    required String screenName,
  }) {
    return Builder(
      builder: (context) {
        // Store screen name in widget tree for descendant widgets
        return InheritedScreenName(
          screenName: screenName,
          child: child,
        );
      },
    );
  }

  /// Get current screen name from context
  static String? getScreenName(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<InheritedScreenName>();
    return inherited?.screenName;
  }
}

/// Inherited widget to pass screen name down the widget tree
class InheritedScreenName extends InheritedWidget {
  final String screenName;

  const InheritedScreenName({
    super.key,
    required this.screenName,
    required Widget child,
  }) : super(child: child);

  static InheritedScreenName? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedScreenName>();
  }

  @override
  bool updateShouldNotify(InheritedScreenName oldWidget) {
    return screenName != oldWidget.screenName;
  }
}
