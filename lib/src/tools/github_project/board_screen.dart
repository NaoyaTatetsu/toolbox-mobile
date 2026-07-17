import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shell/shell_scope.dart';
import 'board_view_model.dart';
import 'models.dart';
import 'settings_screen.dart';
import 'status_color.dart';

/// Kanban board for a GitHub Project (v2).
///
/// Columns scroll horizontally; cards can be long-press dragged between
/// columns or moved via the card's action sheet.
class GitHubProjectBoardScreen extends StatefulWidget {
  const GitHubProjectBoardScreen({super.key});

  @override
  State<GitHubProjectBoardScreen> createState() =>
      _GitHubProjectBoardScreenState();
}

class _GitHubProjectBoardScreenState extends State<GitHubProjectBoardScreen> {
  final _vm = BoardViewModel();

  @override
  void initState() {
    super.initState();
    _vm.init();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: ShellScope.maybeOf(context) != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: ShellScope.maybeOf(context)!.openDrawer,
                )
              : null,
          title: _projectSelector(),
          actions: [
            _RefreshButton(
              busy: _vm.isRefreshing || _vm.status == BoardStatus.loading,
              onPressed: _vm.refresh,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ],
        ),
        floatingActionButton: _vm.board?.statusFieldId != null
            ? FloatingActionButton(
                onPressed: _addTask,
                child: const Icon(Icons.add),
              )
            : null,
        body: _body(),
      ),
    );
  }

  Widget _projectSelector() {
    if (_vm.projects.isEmpty) return const Text('GitHub Projects');
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _vm.selectedProjectId,
        isExpanded: true,
        icon: const Icon(Icons.expand_more),
        items: [
          for (final p in _vm.projects)
            DropdownMenuItem(
              value: p.id,
              child: Text(p.title, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id != null) _vm.selectProject(id);
        },
      ),
    );
  }

  Widget _body() {
    switch (_vm.status) {
      case BoardStatus.initial:
      case BoardStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case BoardStatus.needsToken:
        return _message(
          'GitHub トークンが未設定です',
          action: FilledButton(
            onPressed: _openSettings,
            child: const Text('設定を開く'),
          ),
        );
      case BoardStatus.error:
        return _message(
          _vm.errorMessage ?? 'エラーが発生しました',
          action: FilledButton(
            onPressed: _vm.refresh,
            child: const Text('再試行'),
          ),
        );
      case BoardStatus.ready:
        final board = _vm.board;
        if (board == null) {
          return _message('プロジェクトがありません');
        }
        return _boardView(board);
    }
  }

  Widget _message(String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _boardView(Board board) {
    final columns = <(StatusOption?, List<BoardCard>)>[
      if (board.hasUnassigned) (null, board.cardsIn(null)),
      for (final opt in board.statusOptions) (opt, board.cardsIn(opt.id)),
    ];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: columns.length,
      itemBuilder: (context, i) {
        final (opt, cards) = columns[i];
        return _StatusColumn(
          option: opt,
          cards: cards,
          onDropped: (card) {
            if (opt != null) _vm.moveCard(card, opt.id);
          },
          onCardTap: (card) => _showCardActions(card, board),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GitHubProjectSettingsScreen(viewModel: _vm),
      ),
    );
  }

  Future<void> _addTask() async {
    final board = _vm.board;
    if (board == null) return;
    final controller = TextEditingController();
    String? optionId =
        board.statusOptions.isNotEmpty ? board.statusOptions.first.id : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('タスクを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'タイトル'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: optionId,
                decoration: const InputDecoration(labelText: 'ステータス'),
                items: [
                  for (final opt in board.statusOptions)
                    DropdownMenuItem(value: opt.id, child: Text(opt.name)),
                ],
                onChanged: (v) => setState(() => optionId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      try {
        await _vm.addTask(controller.text.trim(), optionId: optionId);
      } on Exception catch (e) {
        _showError(e);
      }
    }
  }

  void _showCardActions(BoardCard card, Board board) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(card.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: card.number != null ? Text('#${card.number}') : null,
            ),
            const Divider(height: 1),
            if (card.url != null)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('GitHub で開く'),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse(card.url!),
                      mode: LaunchMode.externalApplication);
                },
              ),
            for (final opt in board.statusOptions)
              if (opt.id != card.statusOptionId)
                ListTile(
                  leading: Icon(Icons.circle, size: 14,
                      color: statusColor(opt.color)),
                  title: Text('${opt.name} へ移動'),
                  onTap: () {
                    Navigator.pop(context);
                    _vm.moveCard(card, opt.id);
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _showError(Exception e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Refresh button that spins while a refresh is in flight. Even when the
/// refresh finishes quickly it completes a full turn, so a tap always gives
/// visible feedback.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(_RefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !oldWidget.busy) {
      _spin.repeat();
    } else if (!widget.busy && oldWidget.busy) {
      // Finish the current turn instead of stopping abruptly.
      _spin.stop();
      _spin.forward().whenComplete(_spin.reset);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '更新',
      onPressed: widget.busy ? null : widget.onPressed,
      icon: RotationTransition(
        turns: _spin,
        child: Icon(
          Icons.refresh,
          color: widget.busy ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({
    required this.option,
    required this.cards,
    required this.onDropped,
    required this.onCardTap,
  });

  final StatusOption? option;
  final List<BoardCard> cards;
  final ValueChanged<BoardCard> onDropped;
  final ValueChanged<BoardCard> onCardTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(option?.color);
    return DragTarget<BoardCard>(
      onWillAcceptWithDetails: (d) =>
          option != null && d.data.statusOptionId != option!.id,
      onAcceptWithDetails: (d) => onDropped(d.data),
      builder: (context, candidates, _) => Container(
        width: 300,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: candidates.isNotEmpty
                ? color
                : theme.colorScheme.outlineVariant,
            width: candidates.isNotEmpty ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option?.name ?? 'No Status',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${cards.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: cards.length,
                itemBuilder: (context, i) =>
                    _draggableCard(context, cards[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draggableCard(BuildContext context, BoardCard card) {
    final tile = _CardTile(card: card, onTap: () => onCardTap(card));
    return LongPressDraggable<BoardCard>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 284, child: _CardTile(card: card, elevated: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, this.onTap, this.elevated = false});

  final BoardCard card;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: elevated ? 6 : 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_kindIcon, size: 18, color: _kindColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (card.number != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '#${card.number}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _kindIcon => switch (card.kind) {
        CardKind.issue => Icons.adjust,
        CardKind.pullRequest => Icons.merge,
        CardKind.draftIssue => Icons.edit_note,
        CardKind.unknown => Icons.help_outline,
      };

  Color get _kindColor => switch (card.kind) {
        CardKind.issue => const Color(0xFF57AB5A),
        CardKind.pullRequest => const Color(0xFF996EE3),
        _ => const Color(0xFF8C949E),
      };
}
