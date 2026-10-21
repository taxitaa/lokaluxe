import 'package:flutter/widgets.dart';
import 'app_strings.dart';

/// Provides the fixed English interface used throughout the app.
class LocalizationProvider {
  AppStrings get strings => AppStrings.en;
  String get langCode => 'en';
  bool get isEnglish => true;
  bool get isManualOverride => false;
}

extension LocalizationContext on BuildContext {
  AppStrings get strings {
    try {
      // ignore: invalid_use_of_protected_member
      return (getElementForInheritedWidgetOfExactType<
                  _LocalizationInheritedWidget>()
              ?.widget as _LocalizationInheritedWidget?)
          ?.strings ?? AppStrings.en;
    } catch (_) {
      return AppStrings.en;
    }
  }

  AppStrings get s => strings;
}

class _LocalizationInheritedWidget extends InheritedWidget {
  final AppStrings strings;

  const _LocalizationInheritedWidget({
    required this.strings,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LocalizationInheritedWidget old) =>
      strings.langCode != old.strings.langCode;
}

class LocalizationScope extends StatelessWidget {
  final AppStrings strings;
  final Widget child;

  const LocalizationScope({
    super.key,
    required this.strings,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      _LocalizationInheritedWidget(strings: strings, child: child);
}
