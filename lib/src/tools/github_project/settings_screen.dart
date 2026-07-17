import 'package:flutter/material.dart';

import 'board_view_model.dart';

/// Settings for the GitHub Project tool: PAT entry and project selection.
class GitHubProjectSettingsScreen extends StatefulWidget {
  const GitHubProjectSettingsScreen({super.key, required this.viewModel});

  final BoardViewModel viewModel;

  @override
  State<GitHubProjectSettingsScreen> createState() =>
      _GitHubProjectSettingsScreenState();
}

class _GitHubProjectSettingsScreenState
    extends State<GitHubProjectSettingsScreen> {
  final _tokenController = TextEditingController();
  bool _saving = false;
  String? _error;

  BoardViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('GitHub Projects 設定')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Personal Access Token (classic)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'project スコープが必要です(プライベートリポジトリを扱う場合は repo も)。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _vm.hasToken ? '保存済み(変更する場合のみ入力)' : 'ghp_...',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('検証して保存'),
                ),
                const SizedBox(width: 12),
                if (_vm.hasToken)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            await _vm.clearToken();
                            _tokenController.clear();
                          },
                    child: const Text('トークンを削除'),
                  ),
              ],
            ),
            if (_vm.projects.isNotEmpty) ...[
              const Divider(height: 40),
              Text(
                'プロジェクト',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _vm.selectedProjectId,
                onChanged: (id) {
                  if (id != null) _vm.selectProject(id);
                },
                child: Column(
                  children: [
                    for (final p in _vm.projects)
                      RadioListTile<String>(
                        value: p.id,
                        title: Text(p.title),
                        subtitle: Text('#${p.number}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'トークンを入力してください');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _vm.saveToken(token);
      if (mounted) {
        _tokenController.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('トークンを保存しました')));
      }
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
