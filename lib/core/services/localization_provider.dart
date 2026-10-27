import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

class LocalizationProvider extends ChangeNotifier {
  static const _languagePreferenceKey = 'app_language_code';

  AppStrings _strings = AppStrings.id;
  bool _isInitialized = false;

  AppStrings get strings => _strings;
  String get langCode => _strings.langCode;
  bool get isEnglish => langCode == 'en';
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage = preferences.getString(_languagePreferenceKey);
    if (savedLanguage == 'en') {
      _strings = AppStrings.en;
    } else {
      _strings = AppStrings.id;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'id' && languageCode != 'en') {
      throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Unsupported language',
      );
    }
    if (languageCode == langCode) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languagePreferenceKey, languageCode);
    _strings = languageCode == 'id' ? AppStrings.id : AppStrings.en;
    notifyListeners();
  }
}

extension LocalizationContext on BuildContext {
  AppStrings get strings {
    try {
      // ignore: invalid_use_of_protected_member
      return (getElementForInheritedWidgetOfExactType<
                        _LocalizationInheritedWidget
                      >()
                      ?.widget
                  as _LocalizationInheritedWidget?)
              ?.strings ??
          AppStrings.id;
    } catch (_) {
      return AppStrings.id;
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
