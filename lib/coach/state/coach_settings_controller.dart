import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/coach_models.dart';

class CoachSettingsController extends StateNotifier<CoachSettingsState> {
  CoachSettingsController() : super(const CoachSettingsState());

  void setProactiveCheckins(bool v) =>
      state = state.copyWith(proactiveCheckins: v);
  void setDailyMotivation(bool v) => state = state.copyWith(dailyMotivation: v);
  void setWorkoutSuggestions(bool v) =>
      state = state.copyWith(workoutSuggestions: v);
  void setNutritionTips(bool v) => state = state.copyWith(nutritionTips: v);
  void setSleepReminders(bool v) => state = state.copyWith(sleepReminders: v);
  void setPersonality(CoachPersonality p) =>
      state = state.copyWith(personality: p);
  void setFrequency(NotificationFrequency f) =>
      state = state.copyWith(frequency: f);
  void setVoicePreference(CoachVoicePreference v) =>
      state = state.copyWith(voicePreference: v);
  void setSpeechSpeed(CoachSpeechSpeed s) =>
      state = state.copyWith(speechSpeed: s);
  void setAutoReadReplies(bool v) =>
      state = state.copyWith(autoReadReplies: v);
}

final coachSettingsControllerProvider =
    StateNotifierProvider<CoachSettingsController, CoachSettingsState>(
      (ref) => CoachSettingsController(),
    );
