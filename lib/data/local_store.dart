/// Key/value persistence for the small amount of device-local state the app
/// owns: the anonymous device id, favourites and cast votes.
///
/// This is an interface with an in-memory default rather than a direct
/// `shared_preferences` call, because adding that package is a deliberate
/// choice for whoever ships the app (it pulls in platform plugins). Everything
/// above this line is already written against the interface, so switching is a
/// matter of supplying one implementation:
///
/// ```dart
/// class PrefsStore implements LocalStore {
///   PrefsStore(this._prefs);
///   final SharedPreferences _prefs;
///   @override String? getString(String k) => _prefs.getString(k);
///   @override Future<void> setString(String k, String v) => _prefs.setString(k, v);
///   @override List<String> getStringList(String k) => _prefs.getStringList(k) ?? const [];
///   @override Future<void> setStringList(String k, List<String> v) =>
///       _prefs.setStringList(k, v);
///   @override Future<void> remove(String k) => _prefs.remove(k);
/// }
/// ```
///
/// then `ContentRepository(store: PrefsStore(await SharedPreferences.getInstance()))`.
abstract class LocalStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  List<String> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

/// Default implementation. State lives for the life of the process, so
/// favourites and the device id reset on restart until a real [LocalStore] is
/// supplied. Everything else behaves identically.
class MemoryStore implements LocalStore {
  final Map<String, Object> _values = {};

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  List<String> getStringList(String key) =>
      (_values[key] as List?)?.cast<String>() ?? const [];

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = List<String>.from(value);

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
