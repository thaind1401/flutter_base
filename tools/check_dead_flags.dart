// Fails if a configuration flag is declared and no production code reads it.
//
// The bug this is the automated form of: `AppEnvironmentConfig` carried
// `enableCertificatePinning`, set it to `true` in production, and nothing
// consulted it. `core_network` never asked. Two tests asserted its value, so it
// read as both wired and covered, and anyone auditing the config would have
// concluded production traffic was pinned.
//
// A config flag is not an ordinary field. `bool enableX` is a claim that X
// exists and can be switched on, and a reader believes it — that is why it is
// named that way. A claim with nothing behind it is worse than a missing
// feature, because it stops the next person from checking. CLAUDE.md states the
// rule for prose ("do not write a comment or an ADR asserting a guarantee you
// have not implemented"); this applies it to the API.
//
// **Scope is deliberately narrow: boolean fields of `*Config` classes.** The
// first version of this checked every `final bool` in the workspace and
// reported nine, of which one was real: a widget's `readOnly` is declared and
// consumed inside its own `build`, which no cheap textual rule tells apart from
// a flag that is only ever plumbed. A check that cries wolf teaches people to
// add exemptions reflexively, which is worse than no check. Config classes are
// where a flag carries an implied promise, and where the bug actually happened.
//
// **Tests do not count as readers.** A flag whose only consumers are assertions
// about its own value is precisely the dead one — that is the signature, not a
// false positive to tune away.
//
// Run with: make check-flags
import 'dart:io';

/// Flags allowed to have no reader, with the reason.
///
/// For a switch this repository ships deliberately without the feature behind
/// it, because the feature is per-project. The entry is the contract: it records
/// that the gap is known and intended. An entry that gains a reader — or loses
/// its field — is reported, so it cannot outlive its excuse.
const Map<String, String> allowedUnread = <String, String>{
  'enableCertificatePinning':
      'Ships the switch, not the pin. A certificate and a rotation plan are '
      'per-project, and a pin that outlives the cert it names bricks the app '
      'until the store approves an update. Documented on the field and in the '
      "README's Known gaps, including that honouring it means two places — "
      'where ApiClient builds its clients, and resetConnectionPool(), which '
      'replaces both adapters after a network change and would otherwise drop '
      'the pin the first time the user leaves wifi.',
};

/// Classes whose boolean fields are treated as feature switches.
final RegExp configClass = RegExp(r'\bclass\s+(\w*Config)\b');

/// `final bool enableX;` — the shape a switch takes.
final RegExp booleanField = RegExp(r'^\s*final\s+bool\s+([a-z][A-Za-z0-9_]*)\s*;', multiLine: true);

void main() {
  final production = _dartFiles(tests: false);
  final tests = _dartFiles(tests: true);

  final sources = <String, String>{for (final file in production) file.path: file.readAsStringSync()};
  final testSources = [for (final file in tests) file.readAsStringSync()];

  final declared = <({String name, String path, String owner})>[];
  for (final entry in sources.entries) {
    final owner = configClass.firstMatch(entry.value)?.group(1);
    if (owner == null) continue;
    for (final match in booleanField.allMatches(entry.value)) {
      declared.add((name: match.group(1)!, path: entry.key, owner: owner));
    }
  }

  if (declared.isEmpty) {
    stderr.writeln('✖ Found no *Config class with boolean fields. Run this from the repository root.');
    exit(1);
  }

  final unread = <({String name, String path, String owner, bool testOnly})>[];
  for (final flag in declared) {
    // Anywhere in production code but the file that declares it. A flag read
    // only by the class that owns it is still only plumbing.
    final hasReader = sources.entries
        .where((entry) => entry.key != flag.path)
        .any((entry) => _mentions(entry.value, flag.name));
    if (hasReader) continue;

    unread.add((
      name: flag.name,
      path: flag.path,
      owner: flag.owner,
      testOnly: testSources.any((source) => _mentions(source, flag.name)),
    ));
  }

  final failures = <String>[];

  for (final flag in unread) {
    if (allowedUnread.containsKey(flag.name)) continue;
    failures.add(
      '${flag.owner}.${flag.name} (${flag.path})'
      '${flag.testOnly ? ' — only tests read it, which is what a switch with no feature looks like' : ' — nothing reads it'}',
    );
  }

  // A carve-out that quietly became real is as misleading as the dead flag was:
  // the entry keeps saying "not implemented" after somebody implemented it.
  final unreadNames = unread.map((flag) => flag.name).toSet();
  for (final name in allowedUnread.keys) {
    if (!declared.any((flag) => flag.name == name)) {
      failures.add('$name is in allowedUnread but is no longer declared — remove the entry');
    } else if (!unreadNames.contains(name)) {
      failures.add('$name is in allowedUnread but something reads it now — remove the entry');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('✖ Config flags that promise a feature nothing implements:\n');
    for (final failure in failures) {
      stderr.writeln('  $failure');
    }
    stderr.writeln(
      '\nWire the flag up, delete it, or add it to `allowedUnread` in\n'
      'tools/check_dead_flags.dart with the reason it ships unimplemented.',
    );
    exit(1);
  }

  final exempt = allowedUnread.length;
  stdout.writeln(
    '✓ ${declared.length} config flags are read by production code'
    '${exempt == 0 ? '' : ', with $exempt documented as deliberately unimplemented'}',
  );
}

/// Deliberately textual rather than an AST walk. This runs in `make ci` on every
/// push, `package:analyzer` would make it an order of magnitude slower, and the
/// question — does this identifier appear anywhere else at all — needs no type
/// resolution. Textual matching errs toward *not* reporting, which is the right
/// direction: a false positive here accuses working code.
bool _mentions(String source, String name) => RegExp('\\b$name\\b').hasMatch(source);

List<File> _dartFiles({required bool tests}) {
  final files = <File>[];

  for (final root in ['app', 'core', 'features', 'mini_apps']) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;

      // Build output and package caches hold copies of real sources; counting
      // them would let a stale artifact answer "something reads it".
      if (path.contains('/.dart_tool/') || path.contains('/build/') || path.contains('/.fvm/')) continue;
      if (path.endsWith('.g.dart') || path.endsWith('.config.dart') || path.endsWith('.module.dart')) continue;
      if (path.contains('/generated/')) continue;

      final isTest = path.contains('/test/') || path.contains('/integration_test/');
      if (isTest != tests) continue;

      files.add(entity);
    }
  }
  return files;
}
