import 'package:openhub_windows/src/ui/features/api_keys_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creation omits an empty model-source scope', () {
    final mutation = buildSourceAssignmentMutation(
      creating: true,
      initialSourceIds: const <String>[],
      sourceScopeEnabled: false,
      selectedSourceIds: <String>{},
      clearMissingRestriction: false,
    );

    expect(mutation.include, isFalse);
    expect(mutation.ids, isEmpty);
  });

  test('creation sends selected model sources deterministically', () {
    final mutation = buildSourceAssignmentMutation(
      creating: true,
      initialSourceIds: const <String>[],
      sourceScopeEnabled: false,
      selectedSourceIds: <String>{'source-z', 'source-a'},
      clearMissingRestriction: false,
    );

    expect(mutation.include, isTrue);
    expect(mutation.ids, <String>['source-a', 'source-z']);
  });

  test('editing preserves an existing deny-all source scope by omission', () {
    final mutation = buildSourceAssignmentMutation(
      creating: false,
      initialSourceIds: const <String>[],
      sourceScopeEnabled: true,
      selectedSourceIds: <String>{},
      clearMissingRestriction: false,
    );

    expect(mutation.include, isFalse);
  });

  test('deny-all source scope broadens only after explicit confirmation', () {
    final mutation = buildSourceAssignmentMutation(
      creating: false,
      initialSourceIds: const <String>[],
      sourceScopeEnabled: true,
      selectedSourceIds: <String>{},
      clearMissingRestriction: true,
    );

    expect(mutation.include, isTrue);
    expect(mutation.ids, isEmpty);
  });

  test('editing sends a changed source selection', () {
    final mutation = buildSourceAssignmentMutation(
      creating: false,
      initialSourceIds: const <String>['source-a'],
      sourceScopeEnabled: true,
      selectedSourceIds: <String>{'source-b'},
      clearMissingRestriction: false,
    );

    expect(mutation.include, isTrue);
    expect(mutation.ids, <String>['source-b']);
  });
}
