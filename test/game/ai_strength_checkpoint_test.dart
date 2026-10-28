import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tools/ai_strength_checkpoint.dart';

void main() {
  final manifest = <String, Object?>{
    'seedStart': 400000,
    'seeds': 1,
    'players': 2,
    'candidateSha256': 'frozen'
  };
  final row = <String, Object?>{
    'seed': 400000,
    'rotation': 0,
    'finished': false,
    'moves': <Object?>[],
    'config': <String, Object?>{}
  };
  test('resume preserves unfinished committed game and backs up partial tail',
      () {
    final dir = Directory.systemTemp.createTempSync('stones-strength-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/games');
    expect(restoreStrengthCheckpoint(file, manifest, resume: false), isEmpty);
    file.writeAsStringSync('${jsonEncode(row)}\n{"partial');
    expect(restoreStrengthCheckpoint(file, manifest, resume: true), [row]);
    expect(file.readAsStringSync(), '${jsonEncode(row)}\n');
    expect(dir.listSync().where((f) => f.path.contains('.interrupted-')).length,
        1);
    expect(() => restoreStrengthCheckpoint(file, manifest, resume: false),
        throwsStateError);
  });
  test(
      'resume rejects mixed provenance, duplicate games and corrupt complete rows',
      () {
    final dir = Directory.systemTemp.createTempSync('stones-strength-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/games');
    restoreStrengthCheckpoint(file, manifest, resume: false);
    file.writeAsStringSync('${jsonEncode(row)}\n');
    expect(
        () => restoreStrengthCheckpoint(
            file, {...manifest, 'candidateSha256': 'different'},
            resume: true),
        throwsStateError);
    file.writeAsStringSync('${jsonEncode(row)}\n', mode: FileMode.append);
    expect(() => restoreStrengthCheckpoint(file, manifest, resume: true),
        throwsStateError);
    file.writeAsStringSync('corrupt\n');
    expect(() => restoreStrengthCheckpoint(file, manifest, resume: true),
        throwsFormatException);
  });
}
