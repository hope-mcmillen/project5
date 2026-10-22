import 'package:flutter_test/flutter_test.dart';
import 'package:project5/features/jobs/domain/requirement.dart';
import 'package:project5/features/jobs/domain/requirements_state.dart';

SkillRef skill(int i) => SkillRef(id: 'skill-$i', name: 'Skill $i');

RequirementsState withSkills(int required, int preferred) {
  var state = const RequirementsState();
  for (var i = 0; i < required; i++) {
    state = state.add(skill(i));
  }
  for (var i = 0; i < preferred; i++) {
    state = state.add(skill(100 + i), required: false);
  }
  return state;
}

void main() {
  test('new skills are required until 8 are, then preferred', () {
    final state = withSkills(8, 0).add(skill(50));
    expect(state.requiredCount, 8);
    expect(state.items.last.required, isFalse);
    expect(state.items.last.weight, 1);
  });

  test('the required toggle is blocked at 8 with a reason', () {
    final state = withSkills(8, 1);
    expect(state.requiredToggleBlocked(8), contains('Up to 8'));
    expect(identical(state.toggleRequired(8), state), isTrue);
    // Making a required one preferred is always allowed.
    final freed = state.toggleRequired(0);
    expect(freed.requiredCount, 7);
    expect(freed.requiredToggleBlocked(8), isNull);
  });

  test('no more than 15 skills, and no duplicates', () {
    final full = withSkills(8, 7);
    expect(full.total, 15);
    expect(full.addBlocked, isNotNull);
    expect(identical(full.add(skill(999)), full), isTrue);

    final some = withSkills(2, 0);
    expect(identical(some.add(skill(0)), some), isTrue);
  });

  test('toggling keeps default weights in step', () {
    final state = withSkills(1, 0);
    expect(state.items.first.weight, 2);
    final preferred = state.toggleRequired(0);
    expect(preferred.items.first.weight, 1);
    final heavy = state.setWeight(0, 3).toggleRequired(0);
    expect(heavy.items.first.weight, 3);
  });

  test('min years are clamped to 0–99.9 with one decimal', () {
    final state = withSkills(1, 0);
    expect(state.setMinYears(0, -1).items.first.minYears, 0);
    expect(state.setMinYears(0, 250).items.first.minYears, 99.9);
    expect(state.setMinYears(0, 2.46).items.first.minYears, 2.5);
  });

  test('unmapped skills map to taxonomy skills', () {
    final state = RequirementsState(
      unmapped: const [
        UnmappedSkill(raw: 'Auth', required: true, evidence: 'Firebase Auth'),
      ],
    );
    final mapped = state.mapUnmapped(0, skill(1));
    expect(mapped.unmapped, isEmpty);
    expect(mapped.items.single.skill.id, 'skill-1');
    expect(mapped.items.single.required, isTrue);
    expect(mapped.items.single.evidence, 'Firebase Auth');
    expect(mapped.dirty, isTrue);
  });

  test('trimmed skills come back only when there is room', () {
    final trimmed = [RequirementDraft(skill: skill(77), required: false)];
    final full = RequirementsState(
      items: withSkills(8, 7).items,
      trimmed: trimmed,
    );
    expect(identical(full.restoreTrimmed(0), full), isTrue);

    final roomy = full.remove(0).restoreTrimmed(0);
    expect(roomy.trimmed, isEmpty);
    expect(roomy.contains('skill-77'), isTrue);
  });

  test('removing adjusts the selection', () {
    final state = withSkills(3, 0).select(2).remove(0);
    expect(state.selected, 1);
    expect(withSkills(3, 0).select(1).remove(1).selected, isNull);
  });

  test('save payload matches the contract shape', () {
    final item = withSkills(1, 0).setMinYears(0, 2).items.single;
    expect(item.toRpc(), {
      'skill_id': 'skill-0',
      'required': true,
      'min_years': 2.0,
      'weight': 2,
      'evidence': null,
    });
  });
}
