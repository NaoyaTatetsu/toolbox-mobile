// Data models for GitHub Projects (v2) boards.

class Project {
  const Project({required this.id, required this.title, required this.number});

  final String id;
  final String title;
  final int number;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        title: json['title'] as String,
        number: (json['number'] as num).toInt(),
      );
}

class StatusOption {
  const StatusOption({required this.id, required this.name, this.color});

  final String id;
  final String name;

  /// GitHub color enum name: GRAY, BLUE, GREEN, YELLOW, ORANGE, RED, PINK,
  /// PURPLE, or null.
  final String? color;
}

enum CardKind { issue, pullRequest, draftIssue, unknown }

CardKind cardKindFromTypename(String? typename) => switch (typename) {
      'Issue' => CardKind.issue,
      'PullRequest' => CardKind.pullRequest,
      'DraftIssue' => CardKind.draftIssue,
      _ => CardKind.unknown,
    };

/// A repository label attached to an issue/PR (name + GitHub hex color).
class CardLabel {
  const CardLabel({required this.name, required this.colorHex});

  final String name;

  /// 6-digit hex without '#', e.g. "d73a4a".
  final String colorHex;
}

/// A project field value shown on the card (e.g. Priority, End date).
class CardField {
  const CardField({
    required this.name,
    required this.value,
    this.isDate = false,
    this.color,
  });

  final String name;
  final String value;
  final bool isDate;

  /// GitHub option color enum (GRAY, BLUE, ...) for single-select values.
  final String? color;
}

class BoardCard {
  const BoardCard({
    required this.itemId,
    required this.title,
    required this.kind,
    this.number,
    this.url,
    this.statusOptionId,
    this.labels = const [],
    this.fields = const [],
  });

  final String itemId;
  final String title;
  final CardKind kind;
  final int? number;
  final String? url;
  final String? statusOptionId;
  final List<CardLabel> labels;

  /// Non-Status field values to display (single-selects and dates).
  final List<CardField> fields;

  BoardCard withStatus(String? optionId) => BoardCard(
        itemId: itemId,
        title: title,
        kind: kind,
        number: number,
        url: url,
        statusOptionId: optionId,
        labels: labels,
        fields: fields,
      );
}

class Board {
  const Board({
    required this.title,
    required this.statusFieldId,
    required this.statusOptions,
    required this.cards,
  });

  final String title;
  final String? statusFieldId;
  final List<StatusOption> statusOptions;
  final List<BoardCard> cards;

  List<BoardCard> cardsIn(String? optionId) =>
      cards.where((c) => c.statusOptionId == optionId).toList();

  bool get hasUnassigned => cards.any((c) => c.statusOptionId == null);
}

/// One level of the project view's configured sort.
class SortSpec {
  const SortSpec({
    required this.fieldName,
    required this.direction,
    required this.dataType,
    this.optionOrder = const [],
  });

  final String fieldName;

  /// "ASC" or "DESC".
  final String direction;

  /// TITLE, TEXT, NUMBER, DATE, SINGLE_SELECT, ITERATION.
  final String dataType;

  /// Option IDs in configured order — SINGLE_SELECT only.
  final List<String> optionOrder;
}

/// A sortable field value extracted from an item.
sealed class SortVal {
  const SortVal();
}

class SortStr extends SortVal {
  const SortStr(this.value);
  final String value;
}

class SortNum extends SortVal {
  const SortNum(this.value);
  final double value;
}

class SortNone extends SortVal {
  const SortNone();
}

/// Replicates the GitHub project view's multi-level sort.
///
/// [values] maps itemId -> fieldName -> SortVal.
List<BoardCard> sortedCards(
  List<BoardCard> cards,
  List<SortSpec> sortBy,
  Map<String, Map<String, SortVal>> values,
) {
  if (sortBy.isEmpty) return cards;
  final sorted = List<BoardCard>.of(cards);
  sorted.sort((a, b) {
    for (final spec in sortBy) {
      final c = _compareSort(
        _sortKey(a, spec, values[a.itemId]),
        _sortKey(b, spec, values[b.itemId]),
        spec,
      );
      if (c != 0) return c;
    }
    return 0;
  });
  return sorted;
}

SortVal _sortKey(BoardCard card, SortSpec spec, Map<String, SortVal>? values) {
  if (spec.dataType == 'TITLE') return SortStr(card.title);
  return values?[spec.fieldName] ?? const SortNone();
}

int _compareSort(SortVal a, SortVal b, SortSpec spec) {
  // Empty values always sort last, regardless of direction.
  if (a is SortNone && b is SortNone) return 0;
  if (a is SortNone) return 1;
  if (b is SortNone) return -1;

  var c = 0;
  switch (spec.dataType) {
    case 'SINGLE_SELECT':
      final ai = _optionIndex(spec.optionOrder, a);
      final bi = _optionIndex(spec.optionOrder, b);
      c = ai.compareTo(bi);
    case 'NUMBER':
      final an = a is SortNum ? a.value : double.nan;
      final bn = b is SortNum ? b.value : double.nan;
      if (an != bn) c = an < bn ? -1 : 1;
    default: // TEXT, TITLE, DATE, ITERATION
      c = _str(a).toLowerCase().compareTo(_str(b).toLowerCase());
  }
  return spec.direction == 'DESC' ? -c : c;
}

int _optionIndex(List<String> order, SortVal v) {
  final i = order.indexOf(_str(v));
  return i < 0 ? 1 << 30 : i;
}

String _str(SortVal v) => switch (v) {
      SortStr(:final value) => value,
      SortNum(:final value) => value.toString(),
      SortNone() => '',
    };
