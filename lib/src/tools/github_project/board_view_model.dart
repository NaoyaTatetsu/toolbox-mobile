import 'package:flutter/foundation.dart';

import 'github_api.dart';
import 'models.dart';
import 'token_store.dart';

enum BoardStatus { initial, needsToken, loading, ready, error }

/// State holder for the GitHub Project board tool.
class BoardViewModel extends ChangeNotifier {
  BoardViewModel({GitHubApi? api, TokenStore? store})
      : _api = api ?? GitHubApi(),
        _store = store ?? TokenStore();

  final GitHubApi _api;
  final TokenStore _store;

  BoardStatus status = BoardStatus.initial;

  /// True while a refresh is in flight (even when the current board stays
  /// visible). Drives the refresh button's spinner.
  bool isRefreshing = false;

  String? errorMessage;
  String? _token;
  List<Project> projects = const [];
  String? selectedProjectId;
  Board? board;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Project? get selectedProject {
    for (final p in projects) {
      if (p.id == selectedProjectId) return p;
    }
    return null;
  }

  Future<void> init() async {
    _token = await _store.readToken();
    selectedProjectId = await _store.readSelectedProjectId();
    if (!hasToken) {
      status = BoardStatus.needsToken;
      notifyListeners();
      return;
    }
    await refresh();
  }

  /// Validates and saves a new token, then reloads everything.
  Future<void> saveToken(String token) async {
    await _api.verifyLogin(token); // throws if invalid
    await _store.writeToken(token);
    _token = token;
    await refresh();
  }

  Future<void> clearToken() async {
    await _store.deleteToken();
    _token = null;
    projects = const [];
    board = null;
    status = BoardStatus.needsToken;
    notifyListeners();
  }

  Future<void> selectProject(String projectId) async {
    if (selectedProjectId == projectId) return;
    selectedProjectId = projectId;
    board = null;
    await _store.writeSelectedProjectId(projectId);
    await refresh();
  }

  Future<void> refresh() async {
    if (!hasToken) {
      status = BoardStatus.needsToken;
      notifyListeners();
      return;
    }
    // Keep showing the current board during pull-to-refresh.
    if (board == null) {
      status = BoardStatus.loading;
    }
    isRefreshing = true;
    notifyListeners();
    try {
      projects = await _api.listProjects(_token!);
      if (projects.isNotEmpty &&
          !projects.any((p) => p.id == selectedProjectId)) {
        selectedProjectId = projects.first.id;
        await _store.writeSelectedProjectId(selectedProjectId);
      }
      if (selectedProjectId != null) {
        board = await _api.fetchBoard(_token!, selectedProjectId!);
      } else {
        board = null;
      }
      status = BoardStatus.ready;
      errorMessage = null;
    } on Exception catch (e) {
      errorMessage = e.toString();
      status = board == null ? BoardStatus.error : BoardStatus.ready;
    }
    isRefreshing = false;
    notifyListeners();
  }

  /// Optimistically moves a card, then syncs with GitHub.
  Future<void> moveCard(BoardCard card, String optionId) async {
    final b = board;
    if (b == null || b.statusFieldId == null) return;
    if (card.statusOptionId == optionId) return;

    board = Board(
      title: b.title,
      statusFieldId: b.statusFieldId,
      statusOptions: b.statusOptions,
      cards: [
        for (final c in b.cards)
          c.itemId == card.itemId ? c.withStatus(optionId) : c,
      ],
    );
    notifyListeners();

    try {
      await _api.updateStatus(
        _token!,
        projectId: selectedProjectId!,
        itemId: card.itemId,
        fieldId: b.statusFieldId!,
        optionId: optionId,
      );
    } on Exception catch (e) {
      errorMessage = e.toString();
      await refresh(); // roll back to server truth
    }
  }

  Future<void> addTask(String title, {String? optionId}) async {
    final b = board;
    if (b == null || _token == null || selectedProjectId == null) return;
    await _api.createTask(
      _token!,
      projectId: selectedProjectId!,
      title: title,
      fieldId: optionId != null ? b.statusFieldId : null,
      optionId: optionId,
    );
    await refresh();
  }
}
