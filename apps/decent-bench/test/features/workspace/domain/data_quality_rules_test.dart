import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  test('default profile builder creates schema-derived checks', () {
    final schema = FakeWorkspaceGateway().snapshot;

    final profile = const DefaultQualityProfileBuilder().build(
      schema: schema,
      now: DateTime.utc(2026, 5, 22),
    );

    expect(profile.name, 'Default Import Quality');
    expect(
      profile.rules.map((rule) => rule.ruleType),
      containsAll(<ValidationRuleType>[
        ValidationRuleType.required,
        ValidationRuleType.unique,
      ]),
    );
    expect(profile.validate(), isEmpty);
  });
}
