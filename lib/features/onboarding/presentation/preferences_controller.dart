import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../profile/data/profile_repository.dart';
import '../../deck/presentation/feed_controller.dart';

class PreferencesState {
  const PreferencesState(this.preferences, {this.saving = false, this.error});
  final Preferences preferences;
  final bool saving;
  final String? error;
}

final preferencesControllerProvider =
    AsyncNotifierProvider.autoDispose<PreferencesController, PreferencesState>(
      PreferencesController.new,
    );

class PreferencesController extends AsyncNotifier<PreferencesState> {
  @override
  Future<PreferencesState> build() async => PreferencesState(
    await ref.watch(profileRepositoryProvider).preferences(),
  );
  void set(String key, Object? value) {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    final json = current.preferences.toJson();
    if (value == null) {
      json.remove(key);
    } else {
      json[key] = value;
    }
    state = AsyncData(PreferencesState(Preferences.fromJson(json)));
  }

  bool addLocation(String value) {
    final current = state.asData?.value;
    if (current == null || current.saving) return false;
    final locations = current.preferences.locations ?? [];
    final name = value.trim();
    if (name.isEmpty || name.length > 120 || locations.length >= 50) {
      state = AsyncData(
        PreferencesState(
          current.preferences,
          error: 'Enter a location up to 120 characters, with no more than 50 locations.',
        ),
      );
      return false;
    }
    if (!locations.any((v) => v.toLowerCase() == name.toLowerCase())) {
      set('locations', [...locations, name]);
    }
    return true;
  }

  void toggle(String field, String value) {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    final list = List<String>.from(
      current.preferences.toJson()[field] as List? ?? [],
    );
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
    set(field, list);
  }

  Future<bool> save() async {
    final current = state.asData?.value;
    if (current == null || current.saving) return false;
    state = AsyncData(PreferencesState(current.preferences, saving: true));
    try {
      await ref
          .read(profileRepositoryProvider)
          .savePreferences(current.preferences);
      if (ref.mounted) {
        state = AsyncData(PreferencesState(current.preferences));
        ref.invalidate(feedControllerProvider);
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = AsyncData(
          PreferencesState(
            current.preferences,
            error: error is AppFailure
                ? error.message
                : 'Your preferences could not be saved. Try again.',
          ),
        );
      }
      return false;
    }
  }

  Future<void> setStretch(bool include) async {
    final previous = state.asData?.value;
    if (previous == null || previous.saving) return;
    set('include_stretch', include);
    if (!await save() && ref.mounted) {
      state = AsyncData(
        PreferencesState(
          previous.preferences,
          error: state.asData?.value.error,
        ),
      );
    }
  }
}
