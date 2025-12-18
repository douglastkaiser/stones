import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'achievements_provider.dart';
import 'settings_provider.dart';

class UnlockedCosmetics {
  final BoardThemeDefinition boardTheme;
  final PieceStyleDefinition pieceStyle;

  const UnlockedCosmetics({
    required this.boardTheme,
    required this.pieceStyle,
  });
}

bool _isUnlocked(
  AchievementState achievements,
  AchievementType? requirement,
) {
  if (requirement == null) return true;
  return achievements.unlocked.contains(requirement);
}

BoardThemeDefinition _resolveBoardTheme(
  String id,
  AchievementState achievements,
) {
  final selected = boardThemeById(id);
  if (_isUnlocked(achievements, selected.unlockRequirement)) {
    return selected;
  }
  return boardThemes.first;
}

PieceStyleDefinition _resolvePieceStyle(
  String id,
  AchievementState achievements,
) {
  final selected = pieceStyleById(id);
  if (_isUnlocked(achievements, selected.unlockRequirement)) {
    return selected;
  }
  return pieceStyles.first;
}

final activeCosmeticsProvider = Provider<UnlockedCosmetics>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final achievements = ref.watch(achievementsProvider);

  final boardTheme =
      _resolveBoardTheme(settings.boardThemeId, achievements);
  final pieceStyle =
      _resolvePieceStyle(settings.pieceStyleId, achievements);

  return UnlockedCosmetics(boardTheme: boardTheme, pieceStyle: pieceStyle);
});

final boardUnlockMapProvider = Provider<Map<String, bool>>((ref) {
  final achievements = ref.watch(achievementsProvider);
  return {
    for (final theme in boardThemes)
      theme.id: _isUnlocked(achievements, theme.unlockRequirement),
  };
});

final pieceUnlockMapProvider = Provider<Map<String, bool>>((ref) {
  final achievements = ref.watch(achievementsProvider);
  return {
    for (final style in pieceStyles)
      style.id: _isUnlocked(achievements, style.unlockRequirement),
  };
});
