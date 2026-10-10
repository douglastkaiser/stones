/// Original composed positions, rather than claimed historical match records.
class Study<S> {
  const Study(this.id, this.title, this.phase, this.difficulty, this.moves,
      this.initial, this.hints, this.explanation);
  final String id;
  final String title;
  final String phase;
  final String difficulty;
  final int moves;
  final S initial;
  final List<String> hints;
  final String explanation;
}
