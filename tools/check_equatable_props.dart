// Fails the build when an Equatable class declares a field it leaves out of
// `props`.
//
// Rule 13 says every state class lists every field in `props`, and gives the
// reason: `BlocSelector` and `buildWhen` both decide by `==`, so a field missing
// from `props` never rebuilds anything. Nothing enforced that. The failure is
// silent in the worst way — the state is correct, the widget is correct, and the
// screen simply does not update.
//
// This repository has already paid for one bug in that family: `SessionStore`
// deduplicated its notifications on the status alone, so a profile change at an
// unchanged status published nothing. Same shape, one layer down: equality
// computed over too few fields.
//
// Run with: make check-props
import 'dart:io';

/// Class members are indented exactly two spaces by `dart format`; locals inside
/// a method body are indented four or more. That is what separates
/// `final String id;` (a field) from `final merged = page.merge(next);` (a
/// local), without parsing Dart properly.
final RegExp _field = RegExp(r'^  (?:@override\s+)?(?:late\s+)?final\s+[\w<>,?\s]+?\s+(\w+)\s*[;=]', multiLine: true);

final RegExp _propsGetter = RegExp(r'List<Object\?>\s+get\s+props\s*=>\s*(?:const\s*)?\[([^\]]*)\]');

final RegExp _classDeclaration = RegExp(
  r'^(?:final |sealed |abstract |base |interface )*class\s+(\w+)',
  multiLine: true,
);

/// Fields that are legitimately outside `props`, written down with the reason.
///
/// Same intent as `packagesWithoutTests` and `packageExemptions` elsewhere in
/// `tools/`: an exclusion that is a deliberate design decision gets recorded and
/// reviewed rather than left looking like an oversight. Keyed by class, then by
/// field. An entry that stops being needed is reported so it can be removed.
const Map<String, Map<String, String>> allowedOmissions = <String, Map<String, String>>{
  'Failure': {
    'cause': 'the object the transport threw; compares by identity, so it would make every failure unique',
    'stackTrace': 'a diagnostic, not identity — two identical failures raised at different call sites must be equal',
  },
};

void main() {
  final roots = ['app/lib', 'core', 'features', 'mini_apps'];
  final files = <File>[];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    files.addAll(
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.path.contains('/lib/'))
          // Generated code writes its own equality and is not ours to police.
          .where(
            (file) =>
                !file.path.endsWith('.g.dart') &&
                !file.path.endsWith('.config.dart') &&
                !file.path.endsWith('.module.dart') &&
                !file.path.contains('/generated/'),
          ),
    );
  }

  final problems = <String>[];
  var checked = 0;

  for (final file in files) {
    final source = file.readAsStringSync();
    if (!source.contains('get props')) continue;

    for (final body in _classBodies(source)) {
      final props = _propsGetter.firstMatch(body.source);
      if (props == null) continue;
      checked++;

      final listed = props.group(1)!.split(',').map((entry) => entry.trim()).where((entry) => entry.isNotEmpty).toSet();

      // Only the part of the class above `props` is scanned for fields, so a
      // `final` inside a method declared after it cannot be mistaken for one.
      final declared = _field
          .allMatches(body.source)
          .map((match) => match.group(1)!)
          .where((name) => !name.startsWith('_'))
          .toSet();

      final exempt = allowedOmissions[body.name] ?? const <String, String>{};
      final missing = declared.difference(listed).difference(exempt.keys.toSet());
      if (missing.isNotEmpty) {
        problems.add('${file.path} · ${body.name} omits ${missing.join(', ')} from props');
      }

      // A carve-out that no longer applies is how a temporary exception becomes
      // permanent, so it is reported the same way a missing field is.
      final stale = exempt.keys.where((field) => !declared.contains(field) || listed.contains(field));
      for (final field in stale) {
        problems.add('${file.path} · ${body.name}.$field no longer needs its entry in allowedOmissions');
      }
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('✖ Equatable classes with fields missing from props:\n');
    for (final problem in problems) {
      stderr.writeln('  $problem');
    }
    stderr.writeln(
      '\nA field outside props is invisible to `==`, so BlocSelector and buildWhen\n'
      'never rebuild for it. Add it, or make it a getter if it is derived.',
    );
    exit(1);
  }

  stdout.writeln('✓ $checked Equatable classes list every field in props');
}

/// A class name paired with its body text.
typedef _ClassBody = ({String name, String source});

/// Splits a file at class declarations. Crude on purpose: it only has to
/// attribute fields and a `props` getter to the right class, and the repository
/// is consistently formatted.
List<_ClassBody> _classBodies(String source) {
  final matches = _classDeclaration.allMatches(source).toList();
  return [
    for (var i = 0; i < matches.length; i++)
      (
        name: matches[i].group(1)!,
        source: source.substring(matches[i].start, i + 1 < matches.length ? matches[i + 1].start : source.length),
      ),
  ];
}
