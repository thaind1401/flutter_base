// Enforces the three invariants that per-package localization needs and that
// nothing in Dart, Flutter or the analyzer will check for you.
//
// Splitting the ARB per package (ADR-0011) buys a feature ownership of its own
// copy. What it costs is that `Localizations.of<T>` resolves **by type** at
// runtime, so every way of getting it wrong is invisible until a specific screen
// is opened in a specific language:
//
//   1. a package owns an ARB but is missing from L10N_PACKAGES — `make l10n`
//      never generates it, and the barrel exports a file nobody produced;
//   2. a package is short a locale — the delegate answers `isSupported: false`,
//      the type is then simply absent from the tree, and `of(context)` throws.
//      There is no English fallback. One missing .arb is a crash in that
//      language and nothing else;
//   3. a generated class's delegate is never registered by the host — same
//      crash, in every language, the first time one of that package's screens
//      opens.
//
// All three compile. All three pass `analyze`, `test` and `golden`. This is the
// same shape as the missing DI micro-package module that once white-screened the
// app with the whole gate green, so it gets the same treatment: a check in `make
// ci` rather than a paragraph in a README.
//
// Run with: make check-l10n
import 'dart:convert';
import 'dart:io';

/// Where the host assembles the delegate list. The one file that has to name
/// every generated class, and therefore the one file that can forget one.
const String delegateRegistry = 'app/lib/app/l10n/app_localizations.dart';

/// String literals that sit in a copy position but are not copy.
///
/// Same intent as `allowedOmissions` in check_equatable_props.dart: an exception
/// is written down with its reason rather than discovered later. Keep it small —
/// an entry here is a string no translator will ever see.
const Map<String, String> allowedLiterals = <String, String>{};

/// Argument names whose value is rendered to the user.
///
/// Not an exhaustive list of everything that can hold copy, and it does not need
/// to be: it covers the widgets this base ships, so the reference screens cannot
/// regress. Add a name when a new widget introduces one.
const List<String> copyArguments = [
  'label',
  'hint',
  'tooltip',
  'title',
  'message',
  'confirmLabel',
  'cancelLabel',
  'semanticsLabel',
  'helperText',
  'errorText',
  'description',
];

/// The package whose ARB declares the app's supported languages.
///
/// Adding a language is a product decision about the app, not about a design
/// system — so `app` holds the reference set and every other l10n package is
/// measured against it. When this was `core_ui`, a design-system commit could
/// add a locale no feature had translated, which is a crash rather than an
/// untranslated string.
const String localeReferencePackage = 'app';

void main() {
  final root = Directory.current;
  final violations = <String>[];

  final listed = _makefileList(root, 'L10N_PACKAGES');
  if (listed == null) {
    stderr.writeln('✖ the Makefile has no L10N_PACKAGES assignment to check');
    exit(1);
  }

  final discovered = _packagesWithArb(root);

  for (final path in discovered.difference(listed)) {
    violations.add(
      '$path has an l10n.yaml but is not in L10N_PACKAGES — `make l10n` will never '
      'generate it, and anything exporting the generated file will not compile',
    );
  }
  for (final path in listed.difference(discovered)) {
    violations.add('$path is in L10N_PACKAGES but has no l10n.yaml — `flutter gen-l10n` fails there');
  }

  // Only packages that exist on both sides can be inspected further.
  final packages = <String, _L10nPackage>{};
  for (final path in listed.intersection(discovered)) {
    final package = _read(root, path);
    if (package is String) {
      violations.add(package);
      continue;
    }
    packages[path] = package as _L10nPackage;
  }

  final reference = packages.entries.where((entry) => entry.key.split('/').last == localeReferencePackage).firstOrNull;
  if (reference == null) {
    violations.add('no l10n package named "$localeReferencePackage" — nothing declares the app\'s supported locales');
  } else {
    violations.addAll(_localeParity(packages, reference.value, reference.key));
  }

  for (final entry in packages.entries) {
    violations.addAll(_translationGaps(entry.key, entry.value));
  }

  violations.addAll(_delegateRegistration(root, packages));
  violations.addAll(_hardcodedCopy(root));

  if (violations.isEmpty) {
    final locales = reference == null ? const <String>{} : reference.value.locales;
    stdout.writeln(
      '✓ ${packages.length} l10n packages agree on ${locales.length} locales '
      '(${(locales.toList()..sort()).join(', ')}), every key is translated, every delegate is registered',
    );
    return;
  }

  stderr.writeln('✖ ${violations.length} localization problem(s):\n');
  for (final violation in violations..sort()) {
    stderr.writeln('  $violation');
  }
  stderr.writeln(
    '\nNone of these is a compile error, which is the reason this check exists.\n'
    'A delegate that is missing or does not support the active locale is a null\n'
    'crash when that screen opens — not an untranslated string. ADR-0011.',
  );
  exit(1);
}

/// Every l10n package must ship exactly the locale set the app declares.
List<String> _localeParity(Map<String, _L10nPackage> packages, _L10nPackage reference, String referencePath) {
  final violations = <String>[];

  for (final entry in packages.entries) {
    if (entry.key == referencePath) continue;

    final missing = reference.locales.difference(entry.value.locales);
    final extra = entry.value.locales.difference(reference.locales);

    for (final locale in missing) {
      violations.add(
        '${entry.key} has no "$locale" ARB, but $referencePath declares "$locale" supported — '
        '${entry.value.className}.of(context) throws for every user in that language',
      );
    }
    for (final locale in extra) {
      violations.add(
        '${entry.key} ships a "$locale" ARB that $referencePath does not support — '
        'it is dead weight, or $referencePath is missing the locale',
      );
    }
  }

  return violations;
}

/// Every key in a package's template must exist in that package's other locales.
///
/// `flutter gen-l10n` prints a warning for this and carries on, which means it
/// scrolls past in a build log and ships. A missing key falls back to the
/// template language, so the screen renders — in the wrong language, in one
/// place, which is exactly the kind of thing nobody notices until a user reports
/// it.
List<String> _translationGaps(String path, _L10nPackage package) {
  final violations = <String>[];
  final template = package.keysByLocale[package.templateLocale] ?? const <String>{};

  for (final entry in package.keysByLocale.entries) {
    if (entry.key == package.templateLocale) continue;

    final missing = template.difference(entry.value);
    final extra = entry.value.difference(template);

    if (missing.isNotEmpty) {
      violations.add('$path is missing ${missing.length} "${entry.key}" translation(s): ${_preview(missing)}');
    }
    if (extra.isNotEmpty) {
      violations.add(
        '$path has ${extra.length} "${entry.key}" key(s) absent from the '
        '"${package.templateLocale}" template: ${_preview(extra)}',
      );
    }
  }

  return violations;
}

/// Every generated class must have its delegate registered by the host.
List<String> _delegateRegistration(Directory root, Map<String, _L10nPackage> packages) {
  final file = File('${root.path}/$delegateRegistry');
  if (!file.existsSync()) {
    return ['$delegateRegistry not found — nothing assembles the delegate list'];
  }

  final contents = file.readAsStringSync();
  final registered = RegExp(r'(\w+)\.delegate').allMatches(contents).map((match) => match.group(1)!).toSet();

  final violations = <String>[];
  for (final entry in packages.entries) {
    if (registered.contains(entry.value.className)) continue;
    violations.add(
      '${entry.value.className} (${entry.key}) has no delegate in $delegateRegistry — '
      'Localizations.of resolves by type, so its screens throw on first open',
    );
  }
  return violations;
}

/// Fails on a user-visible string literal in a screen.
///
/// Everything above this function checks that the localization machinery is
/// wired correctly. None of it notices the failure that actually happened here:
/// the machinery was wired, and every screen ignored it. 74 keys existed while
/// `login_screen.dart` said `'Welcome back'` — and that file is the one CLAUDE.md
/// tells every new feature to copy, so the habit propagated faster than the rule
/// could argue with it.
///
/// Scope is deliberately narrow: `presentation/` directories and the host's
/// `shell/`. A literal in `core_ui/src/widgets/` is a *parameter* the caller
/// fills in, not copy, and flagging those would train people to ignore this.
List<String> _hardcodedCopy(Directory root) {
  final violations = <String>[];

  // A quote directly after the opening paren or the argument name. `Text(x)` and
  // `label: context.appL10n.x` do not match; `Text('x')` and `label: 'x'` do.
  final text = RegExp("""Text\\(\\s*['"]([^'"]*)['"]""");
  final argument = RegExp("""\\b(${copyArguments.join('|')}):\\s*['"]([^'"]*)['"]""");

  for (final file in _screenFiles(root)) {
    // The `.` group used to reach `app/` leaves a `./` in the path.
    final relative = file.path.replaceFirst('${root.path}/', '').replaceFirst('./', '');
    final contents = file.readAsStringSync();

    for (final match in [...text.allMatches(contents), ...argument.allMatches(contents)]) {
      final literal = match.group(match.groupCount)!;
      // An empty string is a spacer or a deliberate blank, never copy.
      if (literal.isEmpty) continue;
      if (allowedLiterals.containsKey(literal)) continue;

      violations.add(
        '$relative renders the literal "$literal" — put it in this package\'s ARB '
        'and read it through the package\'s l10n extension (rule 15)',
      );
    }
  }

  return violations;
}

/// Dart files under a `presentation/` or `shell/` directory in any package.
Iterable<File> _screenFiles(Directory root) sync* {
  for (final group in ['core', 'features', 'mini_apps', '.']) {
    final directory = Directory('${root.path}/$group');
    if (!directory.existsSync()) continue;

    for (final package in directory.listSync().whereType<Directory>()) {
      final lib = Directory('${package.path}/lib');
      if (!lib.existsSync()) continue;

      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        if (file.path.contains('/generated/') || file.path.endsWith('.g.dart')) continue;
        if (!file.path.contains('/presentation/') && !file.path.contains('/shell/')) continue;
        yield file;
      }
    }
  }
}

/// One package's ARB directory, as the check needs to see it.
final class _L10nPackage {
  const _L10nPackage({required this.className, required this.templateLocale, required this.keysByLocale});

  /// The generated class, e.g. `AuthL10n`. This is the name the host must
  /// register and the name `Localizations.of` keys on.
  final String className;

  final String templateLocale;
  final Map<String, Set<String>> keysByLocale;

  Set<String> get locales => keysByLocale.keys.toSet();
}

/// Reads one package's l10n.yaml and its ARB files. Returns a violation string
/// rather than throwing, so one broken package does not hide the others.
Object _read(Directory root, String path) {
  final config = File('${root.path}/$path/l10n.yaml').readAsStringSync();

  final arbDir = _yamlValue(config, 'arb-dir');
  final template = _yamlValue(config, 'template-arb-file');
  final className = _yamlValue(config, 'output-class');

  if (arbDir == null || template == null || className == null) {
    return '$path/l10n.yaml must set arb-dir, template-arb-file and output-class';
  }

  final directory = Directory('${root.path}/$path/$arbDir');
  if (!directory.existsSync()) {
    return '$path/l10n.yaml points arb-dir at "$arbDir", which does not exist';
  }

  final keysByLocale = <String, Set<String>>{};
  String? templateLocale;

  for (final file in directory.listSync().whereType<File>()) {
    if (!file.path.endsWith('.arb')) continue;

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      return '$path/$arbDir/${file.uri.pathSegments.last} is not valid JSON: ${error.message}';
    }
    if (decoded is! Map<String, dynamic>) {
      return '$path/$arbDir/${file.uri.pathSegments.last} is not a JSON object';
    }

    // `@@locale` rather than the filename: the filename is a convention, this is
    // what gen-l10n actually reads, and a mismatch between the two is its own
    // class of confusing bug.
    final locale = decoded['@@locale'];
    if (locale is! String) {
      return '$path/$arbDir/${file.uri.pathSegments.last} has no "@@locale"';
    }

    // Keys starting with `@` are metadata (`@key` descriptions, `@@locale`).
    keysByLocale[locale] = decoded.keys.where((key) => !key.startsWith('@')).toSet();
    if (file.uri.pathSegments.last == template) templateLocale = locale;
  }

  if (templateLocale == null) {
    return '$path/$arbDir has no template file "$template"';
  }

  return _L10nPackage(className: className, templateLocale: templateLocale, keysByLocale: keysByLocale);
}

/// Packages that own an ARB, found by walking for `l10n.yaml`.
///
/// Discovered rather than declared, so the Makefile list is checked against the
/// tree instead of against itself.
Set<String> _packagesWithArb(Directory root) {
  final found = <String>{};

  for (final group in ['core', 'features', 'mini_apps']) {
    final directory = Directory('${root.path}/$group');
    if (!directory.existsSync()) continue;
    for (final package in directory.listSync().whereType<Directory>()) {
      final name = package.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      if (File('${package.path}/l10n.yaml').existsSync()) found.add('$group/$name');
    }
  }

  if (File('${root.path}/app/l10n.yaml').existsSync()) found.add('app');

  return found;
}

/// Reads one `NAME := a b c` assignment from the Makefile, following `\`
/// continuations. Same shape as the reader in check_dependencies.dart, kept
/// separate so each tool stays runnable on its own with plain `dart run`.
Set<String>? _makefileList(Directory root, String name) {
  final makefile = File('${root.path}/Makefile');
  if (!makefile.existsSync()) return null;

  final pattern = RegExp(r'^(\w+)\s*:?=\s*((?:.*\\\n)*.*)$', multiLine: true);
  for (final match in pattern.allMatches(makefile.readAsStringSync())) {
    if (match.group(1) != name) continue;
    return match.group(2)!.replaceAll('\\\n', ' ').split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toSet();
  }
  return null;
}

/// Pulls one scalar out of l10n.yaml with a regex.
///
/// A YAML package would be more correct and would make this script need
/// `pub get` before it can run, which is the opposite of what a check in the
/// gate wants. These files are six flat lines.
String? _yamlValue(String contents, String key) =>
    RegExp('^$key:\\s*(\\S+)\\s*\$', multiLine: true).firstMatch(contents)?.group(1);

String _preview(Set<String> keys) {
  final sorted = keys.toList()..sort();
  return sorted.length <= 4 ? sorted.join(', ') : '${sorted.take(4).join(', ')} … and ${sorted.length - 4} more';
}
