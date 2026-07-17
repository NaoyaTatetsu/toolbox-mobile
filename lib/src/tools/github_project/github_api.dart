import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class GitHubApiException implements Exception {
  const GitHubApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// GitHub Projects v2 GraphQL client.
class GitHubApi {
  GitHubApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final _endpoint = Uri.parse('https://api.github.com/graphql');

  Future<Map<String, dynamic>> _run(
    String token,
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final http.Response res;
    try {
      res = await _client.post(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'User-Agent': 'MyToolBox',
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      );
    } catch (e) {
      throw GitHubApiException('Network error: $e');
    }
    if (res.statusCode == 401) {
      throw const GitHubApiException('Invalid token (401)');
    }
    if (res.statusCode >= 400) {
      throw GitHubApiException('GitHub returned HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final msg = (errors.first as Map<String, dynamic>)['message'];
      throw GitHubApiException('GitHub error: $msg');
    }
    throw const GitHubApiException('Unexpected response from GitHub');
  }

  /// Validates the token and returns the viewer's login name.
  Future<String> verifyLogin(String token) async {
    final data = await _run(token, 'query { viewer { login } }');
    return ((data['viewer'] as Map<String, dynamic>)['login']) as String;
  }

  Future<List<Project>> listProjects(String token) async {
    const query = '''
query(\$first:Int!) {
  viewer {
    projectsV2(first:\$first, orderBy:{field:TITLE, direction:ASC}) {
      nodes { id title number closed }
    }
  }
}''';
    final data = await _run(token, query, {'first': 30});
    final nodes = (((data['viewer'] as Map<String, dynamic>)['projectsV2']
        as Map<String, dynamic>)['nodes'] as List);
    return nodes
        .cast<Map<String, dynamic>>()
        .where((n) => n['closed'] != true)
        .map(Project.fromJson)
        .toList();
  }

  Future<Board> fetchBoard(String token, String projectId) async {
    const query = '''
query(\$id:ID!) {
  node(id:\$id) {
    ... on ProjectV2 {
      title
      field(name:"Status") {
        ... on ProjectV2SingleSelectField {
          id
          options { id name color }
        }
      }
      views(first:10) {
        nodes {
          layout
          sortByFields(first:10) {
            nodes {
              direction
              field {
                ... on ProjectV2FieldCommon { name dataType }
                ... on ProjectV2SingleSelectField { options { id name color } }
              }
            }
          }
        }
      }
      items(first:100) {
        nodes {
          id
          content {
            __typename
            ... on Issue { title number url }
            ... on PullRequest { title number url }
            ... on DraftIssue { title }
          }
          fieldValueByName(name:"Status") {
            ... on ProjectV2ItemFieldSingleSelectValue { optionId }
          }
          fieldValues(first:30) {
            nodes {
              ... on ProjectV2ItemFieldTextValue {
                text
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldNumberValue {
                number
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldDateValue {
                date
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                optionId
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldIterationValue {
                startDate
                field { ... on ProjectV2FieldCommon { name } }
              }
            }
          }
        }
      }
    }
  }
}''';
    final data = await _run(token, query, {'id': projectId});
    final node = data['node'];
    if (node is! Map<String, dynamic>) {
      throw const GitHubApiException('Project not found');
    }
    return _parseBoard(node);
  }

  Board _parseBoard(Map<String, dynamic> node) {
    final title = node['title'] as String? ?? '';

    String? statusFieldId;
    var statusOptions = const <StatusOption>[];
    final field = node['field'];
    if (field is Map<String, dynamic> && field['id'] != null) {
      statusFieldId = field['id'] as String;
      statusOptions = _parseOptions(field['options']);
    }

    final sortBy = _parseSortSpecs(node['views']);

    final cards = <BoardCard>[];
    final values = <String, Map<String, SortVal>>{};
    final items =
        ((node['items'] as Map<String, dynamic>?)?['nodes'] as List?) ?? [];
    for (final raw in items.cast<Map<String, dynamic>>()) {
      final itemId = raw['id'] as String;
      final content = raw['content'] as Map<String, dynamic>? ?? const {};
      final statusValue = raw['fieldValueByName'];
      cards.add(BoardCard(
        itemId: itemId,
        title: content['title'] as String? ?? '(no title)',
        kind: cardKindFromTypename(content['__typename'] as String?),
        number: (content['number'] as num?)?.toInt(),
        url: content['url'] as String?,
        statusOptionId: statusValue is Map<String, dynamic>
            ? statusValue['optionId'] as String?
            : null,
      ));
      values[itemId] = _parseFieldValues(raw['fieldValues']);
    }

    return Board(
      title: title,
      statusFieldId: statusFieldId,
      statusOptions: statusOptions,
      cards: sortedCards(cards, sortBy, values),
    );
  }

  List<StatusOption> _parseOptions(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .cast<Map<String, dynamic>>()
        .map((o) => StatusOption(
              id: o['id'] as String,
              name: o['name'] as String,
              color: o['color'] as String?,
            ))
        .toList();
  }

  List<SortSpec> _parseSortSpecs(Object? views) {
    if (views is! Map<String, dynamic>) return const [];
    final nodes = (views['nodes'] as List?)?.cast<Map<String, dynamic>>();
    if (nodes == null || nodes.isEmpty) return const [];
    // Prefer the first board-layout view; fall back to the first view.
    final view = nodes.firstWhere(
      (v) => v['layout'] == 'BOARD_LAYOUT',
      orElse: () => nodes.first,
    );
    final sortNodes =
        ((view['sortByFields'] as Map<String, dynamic>?)?['nodes'] as List?) ??
            [];
    final specs = <SortSpec>[];
    for (final s in sortNodes.cast<Map<String, dynamic>>()) {
      final f = s['field'];
      if (f is! Map<String, dynamic> || f['name'] == null) continue;
      specs.add(SortSpec(
        fieldName: f['name'] as String,
        direction: s['direction'] as String? ?? 'ASC',
        dataType: f['dataType'] as String? ?? 'TEXT',
        optionOrder: _parseOptions(f['options']).map((o) => o.id).toList(),
      ));
    }
    return specs;
  }

  Map<String, SortVal> _parseFieldValues(Object? fieldValues) {
    final out = <String, SortVal>{};
    if (fieldValues is! Map<String, dynamic>) return out;
    final nodes = (fieldValues['nodes'] as List?) ?? [];
    for (final v in nodes.cast<Map<String, dynamic>>()) {
      final name =
          ((v['field'] as Map<String, dynamic>?)?['name']) as String?;
      if (name == null) continue;
      if (v['text'] is String) {
        out[name] = SortStr(v['text'] as String);
      } else if (v['number'] is num) {
        out[name] = SortNum((v['number'] as num).toDouble());
      } else if (v['date'] is String) {
        out[name] = SortStr(v['date'] as String);
      } else if (v['optionId'] is String) {
        out[name] = SortStr(v['optionId'] as String);
      } else if (v['startDate'] is String) {
        out[name] = SortStr(v['startDate'] as String);
      }
    }
    return out;
  }

  Future<void> updateStatus(
    String token, {
    required String projectId,
    required String itemId,
    required String fieldId,
    required String optionId,
  }) async {
    const mutation = '''
mutation(\$project:ID!,\$item:ID!,\$field:ID!,\$option:String!) {
  updateProjectV2ItemFieldValue(
    input: {
      projectId: \$project
      itemId: \$item
      fieldId: \$field
      value: {singleSelectOptionId: \$option}
    }
  ) {
    projectV2Item { id }
  }
}''';
    await _run(token, mutation, {
      'project': projectId,
      'item': itemId,
      'field': fieldId,
      'option': optionId,
    });
  }

  Future<String> addDraftIssue(
    String token, {
    required String projectId,
    required String title,
  }) async {
    const mutation = '''
mutation(\$project:ID!,\$title:String!) {
  addProjectV2DraftIssue(
    input: {projectId: \$project, title: \$title}
  ) {
    projectItem { id }
  }
}''';
    final data = await _run(token, mutation, {
      'project': projectId,
      'title': title,
    });
    return (((data['addProjectV2DraftIssue'] as Map<String, dynamic>)[
        'projectItem'] as Map<String, dynamic>)['id']) as String;
  }

  /// Adds a draft issue and optionally moves it to a status column.
  Future<void> createTask(
    String token, {
    required String projectId,
    required String title,
    String? fieldId,
    String? optionId,
  }) async {
    final itemId =
        await addDraftIssue(token, projectId: projectId, title: title);
    if (fieldId != null && optionId != null) {
      await updateStatus(
        token,
        projectId: projectId,
        itemId: itemId,
        fieldId: fieldId,
        optionId: optionId,
      );
    }
  }
}
