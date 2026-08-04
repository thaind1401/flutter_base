// Aggregates every package's lcov.info into one number and fails below a
// threshold.
//
// Per-package coverage reports are easy to ignore; one workspace number that
// CI enforces is not. The threshold starts deliberately low — raise it as the
// project grows, and never lower it to make a build pass.
//
// Run with: make test-coverage
import 'dart:io';

/// Minimum line coverage across the workspace, as a percentage.
///
/// Raised 40 → 70 once core_arch and core_ui were covered, then 70 → 85 once
/// the three laggards were: `core_kit` 55.9 → 83.6, `core_network` 61.5 → 92.0,
/// `feature_auth` 54.7 → 93.9. The workspace sits at 87.3%.
///
/// A threshold far below the real number ratchets nothing — it lets coverage
/// decay for years before anyone hears about it. Two points of headroom is
/// enough to absorb a refactor without becoming a licence to drop ten.
const double threshold = 85;

/// Minimum line coverage for any single package.
///
/// The workspace number alone is not enough. `core_kit` is pure Dart and easy
/// to cover, so it can carry the total on its own while a package with no tests
/// at all sits at 0% and the build stays green — which is roughly how this
/// project ended up with four untested packages. A floor per package makes that
/// impossible to hide.
///
/// Raised 20 → 50 → 60. The reason for stopping at 60 is specific rather than
/// cautious: `app` sits at 64.2% and is now the only package anywhere near the
/// floor. It is the composition root — DI wiring, the router, the shell — and
/// what covers it is `app_smoke_test.dart` booting the real app, not unit tests
/// of glue. 75 is the next step and it needs the shell screens exercised, not a
/// change to this line.
const double packageThreshold = 60;

/// Minimum line coverage for any single **file**.
///
/// The package floor was not enough either, and the proof is on the record:
/// `app` reported a healthy 67.9% while `settings_screen.dart` sat at *one
/// covered line out of forty* — an entire screen, owning the sign-out
/// confirmation and a banner that prints the backend URL, tested by nothing. A
/// package average absorbs one untested file exactly the way a workspace average
/// absorbs one untested package.
///
/// Every threshold here has now been added after something slipped past the
/// previous one. That is the pattern to expect: a mean hides its worst member at
/// whatever granularity you stop measuring.
const double fileThreshold = 50;

/// Files below this many measured lines are not held to [fileThreshold].
///
/// A four-line file at 50% is two lines, and reporting it teaches people to skim
/// this output. The cut-off is deliberately low enough that no screen, bloc,
/// repository or use case falls under it.
const int fileMinimumLines = 10;

/// Files allowed below [fileThreshold], with the reason.
///
/// Reserved for code that genuinely has **no caller yet** — a base class shipped
/// for features this project has not written, a forwarding path that only a
/// mini-app reaches. Not for code that is merely inconvenient to test: that is
/// the case this check exists to surface.
///
/// Keyed by the path as lcov reports it, matched by suffix so the entry does not
/// depend on where the report was generated from.
const Map<String, String> fileExemptions = <String, String>{};

/// Packages allowed below [packageThreshold], with the reason.
///
/// Same intent as `packagesWithoutTests` in check_dependencies.dart: debt is
/// written down and reviewed, not discovered later. An entry that climbs above
/// the floor is reported so it can be removed — `app` was exempted here on the
/// assumption that a composition root is hard to cover, and the check
/// immediately pointed out it was sitting at 64%.
///
/// Empty, and worth keeping that way.
const Map<String, String> packageExemptions = <String, String>{};

/// Generated code and DI wiring have no meaningful branches to test; counting
/// them makes the number describe the generator rather than the project.
final List<RegExp> excludedPaths = [
  RegExp(r'\.g\.dart$'),
  RegExp(r'\.config\.dart$'),
  RegExp(r'\.module\.dart$'),
  RegExp(r'/generated/'),
  RegExp(r'/l10n/'),
];

void main() {
  // The package list comes from the Makefile, not from a directory walk.
  //
  // Walking the tree looked equivalent and was not: a `coverage/` directory left
  // behind by a deleted package still holds an lcov.info, so the report kept
  // counting `mini_app_sample` at 53.0% after the package was removed — dragging
  // the workspace total down by 2.3 points with numbers for code that no longer
  // existed. The walk also silently passed when a package produced no report at
  // all, which is the failure most worth catching: it means the tests did not
  // run with coverage.
  final packages = _testPackagesFromMakefile();

  var totalFound = 0;
  var totalHit = 0;
  final perPackage = <String, ({int found, int hit})>{};
  final perFile = <String, ({int found, int hit})>{};
  final missing = <String>[];

  for (final path in packages) {
    final report = File('$path/coverage/lcov.info');
    if (!report.existsSync()) {
      missing.add(path);
      continue;
    }
    final package = path.split('/').last;
    var skipping = false;
    var found = 0;
    var hit = 0;
    var currentFile = '';

    for (final line in report.readAsLinesSync()) {
      if (line.startsWith('SF:')) {
        skipping = excludedPaths.any((pattern) => pattern.hasMatch(line));
        // Recorded relative to the package, so the report reads the same
        // wherever it was produced.
        currentFile = '$path/${line.substring(3)}';
        continue;
      }
      if (skipping) continue;
      if (line.startsWith('LF:')) {
        final value = int.parse(line.substring(3));
        found += value;
        perFile[currentFile] = (found: value, hit: perFile[currentFile]?.hit ?? 0);
      }
      if (line.startsWith('LH:')) {
        final value = int.parse(line.substring(3));
        hit += value;
        perFile[currentFile] = (found: perFile[currentFile]?.found ?? 0, hit: value);
      }
    }

    perPackage[package] = (found: found, hit: hit);
    totalFound += found;
    totalHit += hit;
  }

  stdout.writeln('\nCoverage by package');
  stdout.writeln('─' * 46);
  final names = perPackage.keys.toList()..sort();
  for (final name in names) {
    final stats = perPackage[name]!;
    stdout.writeln('  ${name.padRight(24)} ${_percent(stats.hit, stats.found)}  (${stats.hit}/${stats.found})');
  }
  stdout.writeln('─' * 46);

  final total = totalFound == 0 ? 0.0 : totalHit / totalFound * 100;
  stdout.writeln('  ${'TOTAL'.padRight(24)} ${_percent(totalHit, totalFound)}  ($totalHit/$totalFound)\n');

  final failures = <String>[];

  // A package listed in TEST_PACKAGES with no report is louder than a wrong
  // number: it means `make test-coverage` did not run there.
  for (final path in missing) {
    failures.add('$path produced no coverage/lcov.info — run `make test-coverage`');
  }

  for (final name in names) {
    final stats = perPackage[name]!;
    if (stats.found == 0) continue;
    final percent = stats.hit / stats.found * 100;
    final exemption = packageExemptions[name];

    if (percent < packageThreshold && exemption == null) {
      failures.add(
        '$name is at ${percent.toStringAsFixed(1)}%, below the ${packageThreshold.toStringAsFixed(0)}% per-package floor',
      );
    }
    if (percent >= packageThreshold && exemption != null) {
      // Stale exemptions are how a temporary carve-out becomes permanent.
      failures.add('$name is at ${percent.toStringAsFixed(1)}% and no longer needs its exemption — remove the entry');
    }
  }

  if (total < threshold) {
    failures.add(
      'the workspace is at ${total.toStringAsFixed(1)}%, below the ${threshold.toStringAsFixed(0)}% threshold',
    );
  }

  // Reported after the package numbers rather than instead of them: the package
  // floor is what catches a whole area going untested, and this is what catches
  // one file hiding inside a healthy area.
  final lowFiles = <({String path, double percent, int found})>[];
  for (final entry in perFile.entries) {
    final stats = entry.value;
    if (stats.found < fileMinimumLines) continue;
    final percent = stats.hit / stats.found * 100;
    final exemption = _exemptionFor(entry.key);

    if (percent < fileThreshold && exemption == null) {
      lowFiles.add((path: entry.key, percent: percent, found: stats.found));
    }
    if (percent >= fileThreshold && exemption != null) {
      failures.add('${entry.key} is at ${percent.toStringAsFixed(1)}% and no longer needs its exemption — remove it');
    }
  }

  if (lowFiles.isNotEmpty) {
    lowFiles.sort((a, b) => a.percent.compareTo(b.percent));
    for (final file in lowFiles) {
      failures.add(
        '${file.path} is at ${file.percent.toStringAsFixed(1)}% of ${file.found} lines, '
        'below the ${fileThreshold.toStringAsFixed(0)}% per-file floor',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('✖ Coverage:\n');
    for (final failure in failures) {
      stderr.writeln('  $failure');
    }
    stderr.writeln('\nRaise the thresholds as the project grows; never lower one to make a build pass.');
    exit(1);
  }

  stdout.writeln(
    '✓ Coverage ${total.toStringAsFixed(1)}% meets the ${threshold.toStringAsFixed(0)}% threshold, '
    'and every package clears ${packageThreshold.toStringAsFixed(0)}%.',
  );
}

/// Reads `TEST_PACKAGES` out of the Makefile.
///
/// The Makefile is the only place package lists live — see its header, and
/// `check_dependencies.dart`, which cross-checks the same lists against the
/// source tree. Duplicating the list here is how the duplicate goes stale, so
/// this parses the one that already exists rather than declaring a second.
List<String> _testPackagesFromMakefile() {
  final makefile = File('Makefile');
  if (!makefile.existsSync()) {
    stderr.writeln('✖ Makefile not found. Run this from the repository root, or via `make test-coverage`.');
    exit(1);
  }

  final buffer = StringBuffer();
  var collecting = false;
  for (final line in makefile.readAsLinesSync()) {
    if (!collecting && !line.startsWith('TEST_PACKAGES')) continue;
    collecting = true;
    // `\` continues the assignment onto the next line, which is how the real
    // list is written — reading only the first line would silently drop half
    // the packages and inflate the total.
    final continued = line.trimRight().endsWith(r'\');
    buffer.write(' ${continued ? line.trimRight().substring(0, line.trimRight().length - 1) : line}');
    if (!continued) break;
  }

  final assignment = buffer.toString();
  final packages = assignment
      .substring(assignment.indexOf(':=') + 2)
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();

  if (packages.isEmpty) {
    stderr.writeln('✖ Could not parse TEST_PACKAGES from the Makefile.');
    exit(1);
  }
  return packages;
}

String _percent(int hit, int found) => found == 0 ? '   n/a' : '${(hit / found * 100).toStringAsFixed(1).padLeft(5)}%';

/// Matched by suffix so an entry survives the report being generated from a
/// different working directory, and so it can be written the way a reader would
/// naturally refer to the file.
String? _exemptionFor(String path) {
  for (final entry in fileExemptions.entries) {
    if (path.endsWith(entry.key)) return entry.value;
  }
  return null;
}
