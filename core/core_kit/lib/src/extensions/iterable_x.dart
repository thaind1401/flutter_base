extension IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? get lastOrNull => isEmpty ? null : last;

  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  Map<K, List<T>> groupBy<K>(K Function(T element) keyOf) {
    final result = <K, List<T>>{};
    for (final element in this) {
      result.putIfAbsent(keyOf(element), () => <T>[]).add(element);
    }
    return result;
  }

  /// Keeps the first occurrence per key. Backends duplicate rows more often
  /// than anyone expects, and a duplicate key crashes a keyed list.
  List<T> distinctBy<K>(K Function(T element) keyOf) {
    final seen = <K>{};
    return [
      for (final element in this)
        if (seen.add(keyOf(element))) element,
    ];
  }

  /// Pairs each element with its index — avoids `asMap().entries` noise.
  Iterable<({int index, T value})> get indexed sync* {
    var i = 0;
    for (final element in this) {
      yield (index: i++, value: element);
    }
  }
}

extension NullableIterableX<T> on Iterable<T>? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  List<T> orEmpty() => this?.toList() ?? <T>[];
}
