/// FIFO, decision-local cache. Ranked groups pay for every retained child state.
class AiSearchCache {
  AiSearchCache({this.capacity = 10000}) : assert(capacity > 0);
  final int capacity;
  final _entries = <String, (Object, int)>{};
  int hits = 0, misses = 0, evictions = 0, weight = 0;
  int get length => _entries.length;
  T? get<T>(String key) {
    final value = _entries[key];
    if (value == null) {
      misses++;
      return null;
    }
    hits++;
    return value.$1 as T;
  }

  void put(String key, Object value, {int cost = 1}) {
    assert(cost > 0);
    if (cost > capacity) return;
    final old = _entries.remove(key);
    if (old != null) weight -= old.$2;
    while (weight + cost > capacity) {
      weight -= _entries.remove(_entries.keys.first)!.$2;
      evictions++;
    }
    _entries[key] = (value, cost);
    weight += cost;
  }
}

enum AiBound { exact, lower, upper }

class AiDuelEntry {
  const AiDuelEntry(this.score, this.bound);
  final double score;
  final AiBound bound;
}
