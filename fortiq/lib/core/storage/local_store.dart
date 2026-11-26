import 'package:shared_preferences/shared_preferences.dart';

/// Versioned, app-local persistence for onboarding and saved base IDs.
class LocalStore {
  const LocalStore();

  static const onboardingCompletedKey = 'fortiq.onboarding.completed.v1';
  static const favouriteIdsKey = 'fortiq.favourites.ids.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Missing completion means this is a first launch.
  Future<bool> loadOnboardingComplete() async {
    final prefs = await _prefs;
    final value = prefs.get(onboardingCompletedKey);
    return value is bool && value;
  }

  /// Resolves only after the completion flag has been accepted for persistence.
  Future<void> completeOnboarding() async {
    final prefs = await _prefs;
    final saved = await prefs.setBool(onboardingCompletedKey, true);
    if (!saved) throw StateError('Could not persist onboarding completion.');
  }

  Future<List<String>> loadFavouriteIds() async {
    final prefs = await _prefs;
    final value = prefs.get(favouriteIdsKey);
    if (value is! List) return <String>[];
    if (value.any((id) => id is! String)) return <String>[];
    return List<String>.unmodifiable(value.cast<String>());
  }

  Future<void> saveFavouriteIds(List<String> ids) async {
    final prefs = await _prefs;
    final snapshot = List<String>.unmodifiable(ids);
    final saved = await prefs.setStringList(favouriteIdsKey, snapshot);
    if (!saved) throw StateError('Could not persist favourite IDs.');
  }
}
