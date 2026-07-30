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
/// Raised 40 → 70 once core_arch and core_ui were covered; the workspace sits
/// at 72.8%. A threshold far below the real number ratchets nothing — it lets
/// coverage decay for years before anyone hears about it.
const double threshold = 70;

/// Minimum line coverage for any single package.
///
/// The workspace number alone is not enough. `core_kit` is pure Dart and easy
/// to cover, so it can carry the total on its own while a package with no tests
/// at all sits at 0% and the build stays green — which is roughly how this
/// project ended up with four untested packages. A floor per package makes that
/// impossible to hide.
///
/// Raised 20 → 50. Not higher yet, and the reason is specific rather than
/// cautious: `feature_auth` sits at 55.7% and `core_kit` at 55.9%. 60 is the
/// next step and it needs those two covered, not a change to this line.
const double packageThreshold = 50;

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

    for (final line in report.readAsLinesSync()) {
      if (line.startsWith('SF:')) {
        skipping = excludedPaths.any((pattern) => pattern.hasMatch(line));
        continue;
      }
      if (skipping) continue;
      if (line.startsWith('LF:')) found += int.parse(line.substring(3));
      if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
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
