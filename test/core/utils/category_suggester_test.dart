import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/category_suggester.dart';
import 'package:link_hive/features/links/models/link_query.dart';

void main() {
  List<String> suggest(String host, [List<NamedCount> history = const []]) =>
      CategorySuggester.suggest(host: host, history: history);

  test('your history beats the built-in map', () {
    expect(suggest('youtube.com', const [NamedCount('Recipes', 6)]), [
      'Recipes',
    ]);
  });

  test('history keeps its order and is capped', () {
    expect(
      suggest('youtube.com', const [
        NamedCount('Watch', 34),
        NamedCount('Recipes', 6),
        NamedCount('Learn', 3),
        NamedCount('Work', 2),
      ]),
      ['Watch', 'Recipes', 'Learn'],
    );
  });

  test('falls back to the built-in map with no history', () {
    expect(suggest('youtube.com'), ['Watch']);
    expect(suggest('amazon.in'), ['Shop']);
    expect(suggest('amazon.co.uk'), ['Shop']);
    expect(suggest('someone.substack.com'), ['Read']);
  });

  test('unknown sites and empty hosts get nothing', () {
    expect(suggest('example.com'), isEmpty);
    expect(suggest(''), isEmpty);
    expect(suggest('', const [NamedCount('Watch', 5)]), isEmpty);
  });
}
