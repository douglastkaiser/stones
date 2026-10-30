/// Actions on a shared Court decision are checked against a room revision.
enum CourtTakebackAction { request, approve, decline, cancel }

class CourtTakeback {
  CourtTakeback({
    required this.requestedBy,
    required this.baseRevision,
    required List<Map<String, dynamic>> retained,
    required List<Map<String, dynamic>> removed,
    required List<String> approvals,
  })  : retained = _records(retained),
        removed = _records(removed),
        approvals = List.unmodifiable(approvals);

  final String requestedBy;
  final int baseRevision;
  final List<Map<String, dynamic>> retained, removed;
  final List<String> approvals;

  static List<Map<String, dynamic>> _records(
          List<Map<String, dynamic>> records) =>
      List.unmodifiable(
          records.map((record) => Map<String, dynamic>.unmodifiable({
                ...record,
                'drops': List<int>.unmodifiable(
                    (record['drops'] as List).cast<int>()),
              })));

  CourtTakeback approve(String uid) => CourtTakeback(
      requestedBy: requestedBy,
      baseRevision: baseRevision,
      retained: retained,
      removed: removed,
      approvals: [...approvals, uid]);

  Map<String, dynamic> toMap() => {
        'requestedBy': requestedBy,
        'baseRevision': baseRevision,
        'retained': retained,
        'removed': removed,
        'approvals': approvals,
      };

  factory CourtTakeback.fromMap(Map<String, dynamic> map) => CourtTakeback(
      requestedBy: map['requestedBy'] as String,
      baseRevision: map['baseRevision'] as int,
      retained: (map['retained'] as List)
          .map((record) => Map<String, dynamic>.from(record))
          .toList(),
      removed: (map['removed'] as List)
          .map((record) => Map<String, dynamic>.from(record))
          .toList(),
      approvals: (map['approvals'] as List).cast<String>());
}
