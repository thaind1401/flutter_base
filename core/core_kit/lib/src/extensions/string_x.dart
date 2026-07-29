extension StringX on String {
  bool get isBlank => trim().isEmpty;

  bool get isNotBlank => !isBlank;

  /// Null when blank. Lets a caller write `text.orNull ?? fallback` instead of
  /// checking emptiness at every call site.
  String? get orNull => isBlank ? null : this;

  String capitalizeFirst() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Collapses runs of whitespace — user-typed search terms and pasted values
  /// arrive with stray tabs and double spaces.
  String get normalizedSpaces => trim().replaceAll(RegExp(r'\s+'), ' ');

  String truncate(int max, {String ellipsis = '…'}) => length <= max ? this : '${substring(0, max)}$ellipsis';

  /// Initials for avatar placeholders: "Nguyen Van A" -> "NA".
  String get initials {
    final parts = normalizedSpaces.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters1.toUpperCase();
    return '${parts.first.characters1}${parts.last.characters1}'.toUpperCase();
  }

  String get characters1 => isEmpty ? '' : substring(0, 1);
}

extension NullableStringX on String? {
  bool get isNullOrBlank => this == null || this!.isBlank;

  bool get isNotNullOrBlank => !isNullOrBlank;

  String orEmpty() => this ?? '';
}
