import 'package:flutter_test/flutter_test.dart';

import 'package:tool_box_mobile/src/tools/github_project/models.dart';

BoardCard card(String id, String title) => BoardCard(
      itemId: id,
      title: title,
      kind: CardKind.issue,
    );

void main() {
  group('sortedCards (view-sort replication)', () {
    test('no sort specs keeps original order', () {
      final cards = [card('b', 'B'), card('a', 'A')];
      final out = sortedCards(cards, const [], const {});
      expect(out.map((c) => c.itemId), ['b', 'a']);
    });

    test('TITLE sorts by card title, case-insensitive', () {
      final cards = [card('1', 'banana'), card('2', 'Apple'), card('3', 'cherry')];
      const spec = SortSpec(
          fieldName: 'Title', direction: 'ASC', dataType: 'TITLE');
      final out = sortedCards(cards, const [spec], const {});
      expect(out.map((c) => c.title), ['Apple', 'banana', 'cherry']);
    });

    test('DESC negates comparison', () {
      final cards = [card('1', 'a'), card('2', 'b')];
      const spec = SortSpec(
          fieldName: 'Title', direction: 'DESC', dataType: 'TITLE');
      final out = sortedCards(cards, const [spec], const {});
      expect(out.map((c) => c.title), ['b', 'a']);
    });

    test('NUMBER compares numerically', () {
      final cards = [card('1', 'x'), card('2', 'y'), card('3', 'z')];
      const spec = SortSpec(
          fieldName: 'Points', direction: 'ASC', dataType: 'NUMBER');
      final values = {
        '1': {'Points': const SortNum(10)},
        '2': {'Points': const SortNum(2)},
        '3': {'Points': const SortNum(30)},
      };
      final out = sortedCards(cards, const [spec], values);
      expect(out.map((c) => c.itemId), ['2', '1', '3']);
    });

    test('empty values sort last even when DESC', () {
      final cards = [card('1', 'x'), card('2', 'y')];
      const spec = SortSpec(
          fieldName: 'Points', direction: 'DESC', dataType: 'NUMBER');
      final values = {
        '2': {'Points': const SortNum(5)},
      };
      final out = sortedCards(cards, const [spec], values);
      expect(out.map((c) => c.itemId), ['2', '1']);
    });

    test('SINGLE_SELECT uses configured option order', () {
      final cards = [card('1', 'x'), card('2', 'y'), card('3', 'z')];
      const spec = SortSpec(
        fieldName: 'Priority',
        direction: 'ASC',
        dataType: 'SINGLE_SELECT',
        optionOrder: ['high', 'mid', 'low'],
      );
      final values = {
        '1': {'Priority': const SortStr('low')},
        '2': {'Priority': const SortStr('high')},
        '3': {'Priority': const SortStr('mid')},
      };
      final out = sortedCards(cards, const [spec], values);
      expect(out.map((c) => c.itemId), ['2', '3', '1']);
    });

    test('multi-level sort falls through on ties', () {
      final cards = [card('1', 'b'), card('2', 'a'), card('3', 'a')];
      const specs = [
        SortSpec(fieldName: 'Title', direction: 'ASC', dataType: 'TITLE'),
        SortSpec(fieldName: 'Points', direction: 'ASC', dataType: 'NUMBER'),
      ];
      final values = {
        '2': {'Points': const SortNum(2)},
        '3': {'Points': const SortNum(1)},
      };
      final out = sortedCards(cards, specs, values);
      expect(out.map((c) => c.itemId), ['3', '2', '1']);
    });
  });
}
