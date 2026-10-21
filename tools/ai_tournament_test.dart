// Flutter/JIT qualification wrapper; native release runner: ai_calibration.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'ai_calibration.dart';

void main() {
  validateCalibrationSelection();
  for (final shape in BoardShape.values
      .where((s) => calibrationShape.isEmpty || s.name == calibrationShape)) {
    for (var tier = 0; tier < 3; tier++) {
      if (calibrationTier >= 0 && tier != calibrationTier) continue;
      test(
          '${shape.name} ${BotLevel.values[tier].name} vs ${BotLevel.values[tier + 1].name}',
          () async {
        final result = await calibrateAi(shape, tier);
        if (calibrationPairs >= 50) qualifyAi(result);
      }, timeout: const Timeout(Duration(hours: 3)));
    }
  }
}
