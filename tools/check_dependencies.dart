// Enforces the layer graph declared in the root pubspec.
//
// Architecture documented in a README is a suggestion; architecture checked in
// CI is a rule. This is what stops the slow drift where one "temporary" import
// from a core package into a feature makes the whole graph cyclic six months
// later, at which point nobody can extract anything.
//
// Run with: make check-deps
import 'dart:io';

/// What each package is allowed to depend on. Anything absent is forbidden.
///
/// The shape of this map is the architecture:
///   * `core_kit` depends on nothing — that is why it stays pure Dart;
///   * `core_*` never depends on a feature or a mini-app;
///   * a `feature_*` never depends on another feature;
///   * a `mini_app_*` reaches the host only through `mini_app_contract`;
///   * only `app` may depend on everything.
const Map<String, Set<String>> allowedDependencies = {
  'core_kit': {},
  'core_storage': {'core_kit'},
  'core_network': {'core_kit'},
  'core_arch': {'core_kit'},
  'core_ui': {'core_kit', 'core_arch'},
  'mini_app_contract': {'core_kit', 'core_arch'},
  'feature_auth': {'core_kit', 'core_arch', 'core_ui', 'core_network', 'core_storage'},
  'app': {'core_kit', 'core_arch', 'core_ui', 'core_network', 'core_storage', 'mini_app_contract', 'feature_auth'},
};

/// The row a mini-app gets when one is added, kept here as a comment rather than
/// as a live entry so nothing has to be invented under pressure later:
///
/// ```dart
/// 'mini_app_yours': {'core_kit', 'core_arch', 'core_ui', 'mini_app_contract'},
/// ```
///
/// Note what is absent from that set: no `feature_*`, and not `app`. Naming
/// either fails this check, which is the enforcement ADR-0007 is about — the
/// contract is the only channel to the host.

/// Packages that legitimately have no tests yet, kept here rather than left
/// implicit.
///
/// Every other package must have at least one `*_test.dart`. This list is the
/// debt, written down: an entry that gains tests fails the check as stale, so
/// the list only ever shrinks. It is empty, and the intent is that it stays
/// that way — a new package arrives with a test or it does not arrive.
const Set<String> packagesWithoutTests = <String>{};

/// Annotations that mean a package must run `build_runner`.
///
/// Anchored at the start of a line so a mention inside a doc comment does not
/// count — `core_arch` documents `@injectable` and `@LazySingleton` in prose
/// while annotating nothing itself.
final RegExp _codegenAnnotation = RegExp(
  r'''^\s*@(injectable|Injectable|lazySingleton|LazySingleton|singleton|Singleton'''
  r'''|InjectableInit|JsonSerializable|RestApi|module|Module|freezed)\b''',
  multiLine: true,
);

/// Every package name the check knows about; imports of anything else (pub.dev
/// packages, Flutter SDK) are not this tool's business.
final Set<String> workspacePackages = allowedDependencies.keys.toSet();

void main(List<String> args) {
  final root = Directory.current;
  final violations = <String>[
    // A package added to the workspace but not to the table below would be
    // exempt from every rule here, silently. With a flat root that is easy to
    // do — the new directory just sits among the others — so the two lists are
    // compared before anything else runs.
    ..._workspaceDrift(root),
    // The Makefile's package lists drive codegen and tests. Nothing used to
    // check them, and that is exactly how `core_ui` shipped with a
    // `@lazySingleton` that was never generated: the app white-screened on the
    // first frame while analyze, test and this very script all reported green.
    ..._makefileDrift(root),
  ];

  for (final entry in allowedDependencies.entries) {
    final package = entry.key;
    final allowed = entry.value;
    final directory = _directoryFor(root, package);

    if (!directory.existsSync()) {
      violations.add('missing package directory: ${directory.path}');
      continue;
    }

    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      // Generated files re-export whatever the generator saw; they are not a
      // design decision and would produce noise.
      if (file.path.contains('.g.dart') || file.path.contains('.config.dart') || file.path.contains('.module.dart')) {
        continue;
      }
      if (file.path.contains('/generated/')) continue;

      final relative = file.path.replaceFirst('${root.path}/', '');
      for (final imported in _importedWorkspacePackages(file)) {
        if (imported == package) continue;
        if (allowed.contains(imported)) continue;
        violations.add('$relative imports "$imported" — $package may only depend on ${_format(allowed)}');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('✓ boundaries, workspace and Makefile lists agree across ${allowedDependencies.length} packages');
    return;
  }

  stderr.writeln('✖ ${violations.length} violation(s):\n');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  stderr.writeln(
    '\nIf a new dependency is genuinely correct, change allowedDependencies in\n'
    'tools/check_dependencies.dart — deliberately, in the same commit, so the\n'
    'reviewer sees the architecture change rather than just the import.\n'
    '\n'
    'If the complaint is about CODEGEN_PACKAGES or TEST_PACKAGES, fix the\n'
    'Makefile rather than this script: those lists are what `make codegen` and\n'
    '`make test` actually iterate over, and CI runs the same targets.',
  );
  exit(1);
}

/// Maps a package name to its directory.
///
/// The group is derived from the name prefix rather than configured, which
/// makes the naming convention self-enforcing: a package called `shared_utils`
/// resolves to no group, fails to be found, and is reported here — so the
/// grouping cannot quietly drift into a fourth, unnamed category.
Directory _directoryFor(Directory root, String package) => Directory('${root.path}/${_pathFor(package)}/lib');

/// The package's path relative to the repository root — the same string the
/// Makefile's package lists use, which is why the drift check can compare them
/// without a second mapping to keep in sync.
String _pathFor(String package) {
  final group = switch (package) {
    'app' => '',
    _ when package.startsWith('core_') => 'core/',
    _ when package.startsWith('feature_') => 'features/',
    _ when package.startsWith('mini_app_') => 'mini_apps/',
    _ => '',
  };
  return '$group$package';
}

/// Compares the root pubspec's `workspace:` list against [allowedDependencies].
///
/// Parsed with a regex rather than a YAML package so this script stays runnable
/// with plain `dart run`, before `pub get` has resolved anything.
List<String> _workspaceDrift(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return const [];

  final block = RegExp(r'^workspace:\n((?:\s*-\s*.+\n)+)', multiLine: true).firstMatch(pubspec.readAsStringSync());
  if (block == null) return const [];

  final declared = RegExp(
    r'-\s*(\S+)',
  ).allMatches(block.group(1)!).map((match) => match.group(1)!.split('/').last).toSet();

  return [
    for (final package in declared.difference(workspacePackages))
      'pubspec.yaml declares "$package" in the workspace, but it has no entry in allowedDependencies',
    for (final package in workspacePackages.difference(declared))
      'allowedDependencies lists "$package", but it is not in the pubspec.yaml workspace',
  ];
}

/// Compares the Makefile's `CODEGEN_PACKAGES` and `TEST_PACKAGES` against what
/// the source tree actually contains.
///
/// Those two lists are hand-maintained, and until this existed nothing noticed
/// when they fell behind. Both directions are checked: a package missing from a
/// list is the failure that white-screened the app, and a package listed but no
/// longer qualifying is a slower kind of waste — `core_arch` sat in
/// CODEGEN_PACKAGES generating nothing, paying for a build_runner run on every
/// developer machine and every CI job.
List<String> _makefileDrift(Directory root) {
  final makefile = File('${root.path}/Makefile');
  if (!makefile.existsSync()) return const ['Makefile not found — cannot check the codegen and test package lists'];

  final contents = makefile.readAsStringSync();
  final codegen = _makefileList(contents, 'CODEGEN_PACKAGES');
  final tests = _makefileList(contents, 'TEST_PACKAGES');
  if (codegen == null || tests == null) {
    return ['Makefile has no ${codegen == null ? 'CODEGEN_PACKAGES' : 'TEST_PACKAGES'} assignment to check'];
  }

  final violations = <String>[];

  for (final package in workspacePackages) {
    final path = _pathFor(package);
    final annotated = _hasCodegenAnnotation(Directory('${root.path}/$path/lib'));
    final tested = _hasTests(Directory('${root.path}/$path/test'));

    if (annotated && !codegen.contains(path)) {
      violations.add(
        '$path carries a codegen annotation but is not in CODEGEN_PACKAGES — '
        'its generated files will be missing everywhere except the machine that last ran build_runner by hand',
      );
    }
    if (!annotated && codegen.contains(path)) {
      violations.add(
        '$path is in CODEGEN_PACKAGES but annotates nothing — the build_runner run there produces no files',
      );
    }
    if (tested && !tests.contains(path)) {
      violations.add('$path has tests that `make test` never runs — add it to TEST_PACKAGES');
    }
    if (!tested && tests.contains(path)) {
      violations.add('$path is in TEST_PACKAGES but has no *_test.dart — `flutter test` fails there');
    }
    if (!tested && !packagesWithoutTests.contains(package)) {
      violations.add(
        '$path has no tests at all — write one, or record the debt by adding "$package" to packagesWithoutTests',
      );
    }
    if (tested && packagesWithoutTests.contains(package)) {
      violations.add(
        '"$package" is in packagesWithoutTests but now has tests — remove the entry and add $path to TEST_PACKAGES',
      );
    }
  }

  for (final listed in {...codegen, ...tests}) {
    if (!workspacePackages.map(_pathFor).contains(listed)) {
      violations.add('the Makefile lists "$listed", which is not a workspace package');
    }
  }

  return violations..sort();
}

/// Reads one `NAME := a b c` assignment, following `\` line continuations.
final RegExp _assignmentPattern = RegExp(r'^(\w+)\s*:?=\s*((?:.*\\\n)*.*)$', multiLine: true);

Set<String>? _makefileList(String contents, String name) {
  for (final match in _assignmentPattern.allMatches(contents)) {
    if (match.group(1) != name) continue;
    return match.group(2)!.replaceAll('\\\n', ' ').split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toSet();
  }
  return null;
}

bool _hasCodegenAnnotation(Directory lib) {
  if (!lib.existsSync()) return false;
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    if (file.path.contains('.g.dart') || file.path.contains('.config.dart') || file.path.contains('.module.dart')) {
      continue;
    }
    if (file.path.contains('/generated/')) continue;
    if (_codegenAnnotation.hasMatch(file.readAsStringSync())) return true;
  }
  return false;
}

bool _hasTests(Directory tests) =>
    tests.existsSync() &&
    tests.listSync(recursive: true).whereType<File>().any((file) => file.path.endsWith('_test.dart'));

final RegExp _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]package:([a-z_0-9]+)/''', multiLine: true);

Iterable<String> _importedWorkspacePackages(File file) sync* {
  for (final match in _importPattern.allMatches(file.readAsStringSync())) {
    final package = match.group(1)!;
    if (workspacePackages.contains(package)) yield package;
  }
}

String _format(Set<String> allowed) => allowed.isEmpty ? 'nothing (it is the root layer)' : allowed.join(', ');
