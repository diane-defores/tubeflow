import 'en.dart';
import 'fr.dart';

/// Supported locales
enum AppLocale { en, fr }

/// Get translations for a locale
Map<String, dynamic> getTranslations(AppLocale locale) {
  switch (locale) {
    case AppLocale.en:
      return en;
    case AppLocale.fr:
      return fr;
  }
}

/// Translation helper — access nested keys with dot notation.
/// Example: t('common.loading') → "Loading..."
String t(String key, {AppLocale locale = AppLocale.en}) {
  final translations = getTranslations(locale);
  final parts = key.split('.');
  dynamic current = translations;

  for (final part in parts) {
    if (current is Map<String, dynamic> && current.containsKey(part)) {
      current = current[part];
    } else {
      return key; // Return key as fallback
    }
  }

  return current?.toString() ?? key;
}

/// Translation helper with parameter substitution.
/// Example: t('hero.socialProof', params: {'count': '500'})
String tr(
  String key, {
  AppLocale locale = AppLocale.en,
  Map<String, String>? params,
}) {
  var result = t(key, locale: locale);
  if (params != null) {
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
  }
  return result;
}
