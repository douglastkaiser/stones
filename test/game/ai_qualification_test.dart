import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tools/ai_qualification.dart'
    show summarize, load, compactTrial, binaryProvenance, sha;

List<Map<String, dynamic>> trials(
        {int wins = 70, int draws = 10, int unfinished = 10}) =>
    [
      for (var i = 0; i < 100; i++)
        <String, dynamic>{
          'group': 'square-5-2:0:1',
          'players': 2,
          'targetSeats': 1,
          'finished': i < 100 - unfinished,
          'winner': i < wins
              ? 'ivory'
              : i < 100 - draws - unfinished
                  ? 'charcoal'
                  : null,
          'targetWon': i < wins,
          'decisions': <Map<String, dynamic>>[]
        }
    ];
void main() {
  test('experiment provenance rejects a replaced executable', () async {
    final directory = Directory.systemTemp.createTempSync('stones-provenance-');
    try {
      final binary = File('${directory.path}/engine')
        ..writeAsStringSync('original');
      final sidecar = File('${binary.path}.manifest.json');
      expect(await binaryProvenance(binary.path), isNull);
      sidecar.writeAsStringSync(jsonEncode({
        'binarySha256': await sha(binary.path),
        'buildSettings': {'fullWidthDuels': true, 'roadResilienceWeight': 16}
      }));
      expect((await binaryProvenance(binary.path))!['buildSettings'],
          {'fullWidthDuels': true, 'roadResilienceWeight': 16});
      binary.writeAsStringSync('replaced');
      await expectLater(binaryProvenance(binary.path), throwsStateError);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
  test(
      'resume removes partial tail and keeps full replay off the in-memory aggregate',
      () async {
    final dir = Directory.systemTemp.createTempSync('stones-ai-resume-');
    try {
      final file = File('${dir.path}/games.jsonl');
      final row = {
        ...trials().first,
        'id': 'done',
        'moves': List.filled(1000, 'full replay')
      };
      file.writeAsStringSync('${jsonEncode(row)}\n{"id":"interrupted');
      final restored = await load(file);
      expect(restored.length, 1);
      expect(restored.first['id'], 'done');
      expect(restored.first.containsKey('moves'), isFalse);
      expect(file.readAsStringSync(), '${jsonEncode(row)}\n');
      file.writeAsStringSync('${jsonEncode({...row, 'id': 'next'})}\n',
          mode: FileMode.append);
      expect((await load(file)).map((r) => r['id']), ['done', 'next']);
      expect(
          summarize(restored, 1, 'adjacent'), summarize([row], 1, 'adjacent'));
      file.writeAsStringSync('not-json\n');
      await expectLater(load(file), throwsFormatException);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
  test('compacted paired timing records preserve percentile gates', () {
    final row = {
      ...trials().first,
      'decisions': [
        for (var i = 0; i < 50; i++)
          {
            'paired': true,
            'candidate': {'elapsedMs': i, 'move': 'excluded'},
            'baseline': {'elapsedMs': i + 1}
          }
      ]
    };
    expect(summarize([compactTrial(row)], 1, 'adjacent'),
        summarize([row], 1, 'adjacent'));
  });

  test('incomplete profiles and absent paired latency never qualify', () {
    final report = summarize(trials(), 50, 'adjacent');
    expect(report['allSelectedStrengthGatesPassed'], isTrue);
    expect(report['matrixComplete'], isFalse);
    expect(report['qualified'], isFalse);
    expect(report['allSelectedLatencyGatesPassed'], isFalse);
  });
  test(
      'too few seeds, completion, decisive share and tier separation fail independently',
      () {
    expect(summarize(trials(), 2, 'adjacent')['allSelectedStrengthGatesPassed'],
        isFalse);
    expect(
        summarize(trials(wins: 65, draws: 0, unfinished: 30), 50, 'adjacent')[
            'allSelectedStrengthGatesPassed'],
        isFalse);
    expect(
        summarize(trials(wins: 30, draws: 60, unfinished: 0), 50, 'adjacent')[
            'allSelectedStrengthGatesPassed'],
        isFalse);
    expect(
        summarize(
            trials(wins: 48), 50, 'adjacent')['allSelectedStrengthGatesPassed'],
        isFalse);
    final groups = summarize(trials(), 50, 'adjacent')['groups'] as List;
    expect(groups.single['unfinished'], 10);
  });
}
