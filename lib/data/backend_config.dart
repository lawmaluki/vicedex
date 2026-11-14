/// Backend endpoints, supplied at build time:
///
/// ```sh
/// flutter run \
///   --dart-define=VICEDEX_PACK_URL=https://cdn.example.com/vicedex/latest.json \
///   --dart-define=VICEDEX_SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=VICEDEX_SUPABASE_ANON_KEY=ey...
/// ```
///
/// All three are optional. With none set the app runs entirely on the bundled
/// content pack: the cheat library, vehicles and search all work, while voting
/// and submitting report that the backend is not configured. That keeps the
/// repo runnable by anyone who clones it without handing out keys.
///
/// The anon key is a public, row-level-security-scoped credential and is meant
/// to ship in the client. The service-role key must never appear here.
class BackendConfig {
  const BackendConfig({String? packUrl, String? supabaseUrl, String? supabaseAnonKey})
      : _packUrl = packUrl,
        _supabaseUrl = supabaseUrl,
        _supabaseAnonKey = supabaseAnonKey;

  /// Reads the three `--dart-define` values. Unset defines come back as the
  /// empty string, which [_orNull] turns into null so callers have one thing
  /// to check.
  static const fromEnvironment = BackendConfig(
    packUrl: String.fromEnvironment('VICEDEX_PACK_URL'),
    supabaseUrl: String.fromEnvironment('VICEDEX_SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('VICEDEX_SUPABASE_ANON_KEY'),
  );

  final String? _packUrl;
  final String? _supabaseUrl;
  final String? _supabaseAnonKey;

  static String? _orNull(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  /// Static content pack (`latest.json`). Null means bundled-only.
  String? get packUrl => _orNull(_packUrl);

  String? get supabaseUrl => _orNull(_supabaseUrl);
  String? get supabaseAnonKey => _orNull(_supabaseAnonKey);

  /// Whether votes, submissions and reports can be sent.
  bool get hasBackend => supabaseUrl != null && supabaseAnonKey != null;
}
