import 'package:flutter/widgets.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

/// App-wide UI state. Frontend only: favourites and votes live in memory.
/// Swap for persistence (shared_preferences / Supabase) when a backend lands.
class AppState extends ChangeNotifier {
  GamePlatform _platform = GamePlatform.ps5;
  final Set<String> _favourites = {};
  final Map<String, int> _votes = {}; // cheatId → +1 works / -1 doesn't

  GamePlatform get platform => _platform;
  List<Cheat> get cheats => MockData.cheats;

  void setPlatform(GamePlatform p) {
    if (p == _platform) return;
    _platform = p;
    notifyListeners();
  }

  bool isFavourite(String id) => _favourites.contains(id);

  void toggleFavourite(String id) {
    if (!_favourites.remove(id)) _favourites.add(id);
    notifyListeners();
  }

  List<Cheat> get favouriteCheats => cheats.where((c) => _favourites.contains(c.id)).toList();

  int? voteFor(String id) => _votes[id];

  void vote(String id, int value) {
    if (_votes[id] == value) {
      _votes.remove(id);
    } else {
      _votes[id] = value;
    }
    notifyListeners();
  }

  /// Displayed tallies: stored confirmations plus this device's vote.
  int worksCount(Cheat c) => c.confirmations + (_votes[c.id] == 1 ? 1 : 0);
  int failsCount(Cheat c) => _votes[c.id] == -1 ? 1 : 0;

  Cheat cheatById(String id) => cheats.firstWhere((c) => c.id == id);
}

/// Makes [AppState] available below it without extra packages.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
