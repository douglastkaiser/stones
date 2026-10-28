// Exact-provenance checkpointing for long native reference trials.
import 'dart:convert';
import 'dart:io';

List<Map<String, dynamic>> restoreStrengthCheckpoint(
    File output, Map<String, Object?> manifest,
    {required bool resume}) {
  final sidecar = File('${output.path}.manifest.json');
  bool sameManifest() =>
      sidecar.existsSync() &&
      jsonEncode(jsonDecode(sidecar.readAsStringSync())) ==
          jsonEncode(manifest);
  if (!output.existsSync()) {
    if (sidecar.existsSync() && (!resume || !sameManifest())) {
      throw StateError(
          'Manifest exists without a matching replay: ${output.path}');
    }
    output.parent.createSync(recursive: true);
    sidecar.writeAsStringSync(jsonEncode(manifest));
    output.writeAsStringSync('');
    return [];
  }
  if (!resume) throw StateError('Output already exists: ${output.path}');
  if (!sameManifest()) {
    throw StateError('Cannot resume different source, binaries or settings');
  }
  final bytes = output.readAsBytesSync();
  final committed = bytes.lastIndexOf(10) + 1;
  // A row is committed only after its newline. Preserve interrupted bytes before
  // truncating; complete rows are never discarded, replayed or outcome-selected.
  final rows = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final line in utf8.decode(bytes.sublist(0, committed)).split('\n')) {
    if (line.isEmpty) continue;
    final row = Map<String, dynamic>.from(jsonDecode(line) as Map);
    final seed = row['seed'];
    final rotation = row['rotation'];
    final start = manifest['seedStart']! as int;
    if (seed is! int ||
        rotation is! int ||
        seed < start ||
        seed >= start + (manifest['seeds']! as int) ||
        rotation < 0 ||
        rotation >= (manifest['players']! as int) ||
        !ids.add('$seed:$rotation') ||
        row['finished'] is! bool ||
        row['moves'] is! List ||
        row['config'] is! Map) {
      throw StateError('Invalid or duplicate committed trial');
    }
    rows.add(row);
  }
  if (committed < bytes.length) {
    File('${output.path}.interrupted-${DateTime.now().microsecondsSinceEpoch}')
        .writeAsBytesSync(bytes.sublist(committed), flush: true);
    final handle = output.openSync(mode: FileMode.append);
    try {
      handle.truncateSync(committed);
    } finally {
      handle.closeSync();
    }
  }
  return rows;
}
