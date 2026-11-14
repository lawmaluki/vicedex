import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/backend_client.dart';
import '../data/content_pack.dart';
import '../data/content_repository.dart';
import '../data/pack_store.dart';
import '../models/models.dart';

/// How far content loading has got, so screens can show a spinner, the data,
/// or an explanation instead of an empty list.
enum LoadStatus { idle, loading, ready, failed }

/// App-wide state: the loaded content pack plus this device's platform choice,
/// favourites and votes.
///
/// Content is read through [ContentRepository]; favourites and votes are
/// written locally first and synced to the backend when one is configured.
class AppState extends ChangeNotifier {
  AppState({ContentRepository? repository})
      : _repo = repository ?? ContentRepository();

  final ContentRepository _repo;

  GamePlatform _platform = GamePlatform.ps5;
  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  ContentPack _pack = ContentPack.empty;
  Set<String> _favourites = {};
  Map<String, int> _votes = {};
  Map<String, CheatTally> _tallies = const {};

  // --- loading --------------------------------------------------------------

  LoadStatus get status => _status;
  Object? get error => _error;
  ContentPack get pack => _pack;
  PackOrigin get packOrigin => _repo.packOrigin;
  bool get hasBackend => _repo.hasBackend;

  /// True when content is being served from the copy inside the app because a
  /// refresh failed. Screens use it to show a quiet "offline" hint.
  bool get isStale => _repo.lastError != null && _status == LoadStatus.ready;

  Future<void> load() async {
    if (_status == LoadStatus.loading) return;
    _status = LoadStatus.loading;
    notifyListeners();

    try {
      _pack = await _repo.load();
      _favourites = _repo.loadFavourites();
      _votes = _repo.loadVotes();
      _status = _pack.isEmpty ? LoadStatus.failed : LoadStatus.ready;
      _error = _pack.isEmpty ? _repo.lastError : null;
    } catch (error, stack) {
      _status = LoadStatus.failed;
      _error = error;
      if (kDebugMode) debugPrintStack(stackTrace: stack, label: 'ViceDex load failed');
    }
    notifyListeners();

    if (_status == LoadStatus.ready) {
      // Fire-and-forget: tallies arrive after the UI is already usable.
      refreshTallies();
    }
  }

  Future<void> refreshTallies() async {
    if (!_repo.hasBackend || _pack.cheats.isEmpty) return;
    final fetched = await _repo.tallies([for (final c in _pack.cheats) c.id]);
    if (fetched.isEmpty) return;
    _tallies = fetched;
    notifyListeners();
  }

  // --- content --------------------------------------------------------------

  /// Codes for this game. Empty until GTA VI cheats are confirmed.
  List<Cheat> get cheats => _pack.currentGameCheats;

  /// Real codes from GTA V, shown as reference while [cheats] is empty.
  List<Cheat> get legacyCheats => _pack.legacyCheats;

  /// What the cheat library should list: the current game's codes when there
  /// are any, otherwise the legacy reference set.
  List<Cheat> get visibleCheats => cheats.isNotEmpty ? cheats : legacyCheats;

  List<Vehicle> get vehicles => _pack.vehicles;
  List<Secret> get secrets => _pack.secrets;

  List<ContentNotice> noticesFor(String scope) => _pack.noticesFor(scope);

  Cheat? cheatById(String id) {
    for (final cheat in _pack.cheats) {
      if (cheat.id == id) return cheat;
    }
    return null;
  }

  /// Search suggestions drawn from the loaded content rather than hard-coded,
  /// so they always match what is actually there.
  List<String> get suggestions {
    final seen = <String>[];
    for (final cheat in visibleCheats) {
      for (final word in cheat.keywords) {
        if (word.length > 3 && !seen.contains(word)) seen.add(word);
        if (seen.length >= 5) return seen;
      }
    }
    return seen;
  }

  // --- platform -------------------------------------------------------------

  GamePlatform get platform => _platform;

  void setPlatform(GamePlatform p) {
    if (p == _platform) return;
    _platform = p;
    notifyListeners();
  }

  // --- favourites -----------------------------------------------------------

  bool isFavourite(String id) => _favourites.contains(id);

  void toggleFavourite(String id) {
    if (!_favourites.remove(id)) _favourites.add(id);
    notifyListeners();
    _repo.saveFavourites(_favourites);
  }

  List<Cheat> get favouriteCheats =>
      _pack.cheats.where((c) => _favourites.contains(c.id)).toList(growable: false);

  // --- votes ----------------------------------------------------------------

  /// This device's vote on [id] for the selected platform.
  int? voteFor(String id) => _votes[ContentRepository.voteKey(id, _platform)];

  /// Casts or withdraws a vote. Tapping the same button again withdraws it.
  ///
  /// The local change is applied first so the UI responds immediately; a
  /// backend failure is reported through [voteError] without rolling back,
  /// because the vote is still true of this device.
  Future<void> vote(String id, int value) async {
    final key = ContentRepository.voteKey(id, _platform);
    final next = _votes[key] == value ? 0 : value;
    if (next == 0) {
      _votes.remove(key);
    } else {
      _votes[key] = next;
    }
    _voteError = null;
    notifyListeners();

    try {
      await _repo.vote(cheatId: id, platform: _platform, value: next);
    } on BackendException catch (error) {
      _voteError = error.message;
      notifyListeners();
    } catch (_) {
      _voteError = 'Your vote is saved on this device but could not be sent.';
      notifyListeners();
    }
  }

  String? _voteError;
  String? get voteError => _voteError;
  void clearVoteError() {
    if (_voteError == null) return;
    _voteError = null;
    notifyListeners();
  }

  /// Confirmed-working count: the server tally when available, otherwise the
  /// count baked into the pack, plus this device's own vote.
  int worksCount(Cheat c) {
    final tally = _tallies[ContentRepository.voteKey(c.id, _platform)];
    final base = tally?.works ?? c.confirmations;
    return base + (voteFor(c.id) == 1 ? 1 : 0);
  }

  int failsCount(Cheat c) {
    final tally = _tallies[ContentRepository.voteKey(c.id, _platform)];
    return (tally?.fails ?? 0) + (voteFor(c.id) == -1 ? 1 : 0);
  }

  // --- community writes -----------------------------------------------------

  Future<String> submitCheat({
    required String title,
    required CheatCategory category,
    required List<String> sequence,
    String? summary,
    String? sourceNote,
  }) =>
      _repo.submitCheat(
        title: title,
        category: category,
        platform: _platform,
        sequence: sequence,
        summary: summary,
        sourceNote: sourceNote,
      );

  Future<void> reportCheat({required String cheatId, required String reason}) =>
      _repo.reportCheat(cheatId: cheatId, reason: reason, platform: _platform);

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }
}

/// Makes [AppState] available below it without extra packages.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
