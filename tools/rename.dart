// One-command rebrand of the template.
//
//   make rename NAME="Acme Field" ORG=com.acme.field
//
// What it changes, and what it deliberately does not:
//
//   * changes the Android applicationId and namespace, the iOS bundle
//     identifier, the launcher/display name on both platforms, and the Kotlin
//     package — including moving the source tree, since a Kotlin package is a
//     directory path and a text replace alone leaves the file where it was and
//     breaks the build;
//   * leaves every Dart package name alone. The host package is always `app`
//     and the shared packages are always `core_*` / `feature_*`, so a rename
//     never touches a single `import`. That is the point: renaming Dart
//     packages means rewriting thousands of imports, and every later merge from
//     the template then conflicts on all of them.
//
// It is idempotent: the current identifier is read from the project rather than
// assumed, so running it twice, or after a partial run, does the right thing.
//
// Colors, fonts and the app icon are untouched — those are design decisions,
// not a find-and-replace. See docs/theming.md.
import 'dart:io';

void main(List<String> args) {
  final options = _parseArgs(args);
  if (options == null) {
    stderr.writeln('Usage: make rename NAME="My App" ORG=com.acme.myapp');
    exit(64);
  }

  final (name, org) = options;
  final orgError = _validateOrg(org);
  if (orgError != null) {
    stderr.writeln('✖ $orgError');
    exit(65);
  }

  final root = Directory.current;
  final currentId = _currentApplicationId(root);
  if (currentId == null) {
    stderr.writeln('✖ Could not read the current applicationId from app/android/app/build.gradle.kts.');
    exit(66);
  }

  // Must return, not just report. Continuing with from == to makes the package
  // move write each file onto itself and then delete it — which silently
  // removed MainActivity.kt the first time this ran twice.
  if (currentId == org) {
    stdout.writeln('· already named $org — nothing to do');
    stdout.writeln('  (to change only the display name, edit AndroidManifest.xml and Info.plist)');
    return;
  }

  stdout.writeln('Renaming "$currentId" → "$org", display name "$name"…\n');

  _renameAndroid(root, name: name, from: currentId, to: org);
  _renameIos(root, name: name, from: currentId, to: org);
  _renameWorkspace(root, name);

  stdout.writeln(
    '\n✓ Done.\n\n'
    'Next steps this tool leaves to you on purpose:\n'
    '  1. app/env_config/*/dart_defines.json — point BASE_URL at your API.\n'
    '  2. packages/core_ui/lib/src/theme/app_colors.dart — your brand palette.\n'
    '  3. App icon and splash assets.\n'
    '  4. git remote set-url origin <your repo>\n'
    '  5. make rebuild && make ci\n',
  );
}

(String, String)? _parseArgs(List<String> args) {
  String? name;
  String? org;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--name') name = args[i + 1];
    if (args[i] == '--org') org = args[i + 1];
  }
  if (name == null || name.trim().isEmpty || org == null || org.trim().isEmpty) return null;
  return (name.trim(), org.trim());
}

/// Both stores and the Android build reject anything outside this shape, and
/// the failure surfaces much later — at upload time — if it is not caught here.
String? _validateOrg(String org) {
  if (!RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(org)) {
    return 'ORG must be lowercase reverse-DNS with at least two segments, e.g. com.acme.myapp.\n'
        '  Each segment must start with a letter; hyphens and capitals are not allowed. Got: "$org"';
  }
  // `MainActivity` would land in a package whose last segment is a Kotlin
  // keyword and fail to compile.
  const reserved = {'in', 'is', 'as', 'for', 'fun', 'val', 'var', 'object', 'when', 'class', 'package'};
  final bad = org.split('.').where(reserved.contains);
  if (bad.isNotEmpty) return 'ORG segment "${bad.first}" is a Kotlin keyword; pick another.';
  return null;
}

File _gradleFile(Directory root) => File('${root.path}/app/android/app/build.gradle.kts');

String? _currentApplicationId(Directory root) {
  final gradle = _gradleFile(root);
  if (!gradle.existsSync()) return null;
  final match = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle.readAsStringSync());
  return match?.group(1);
}

void _renameAndroid(Directory root, {required String name, required String from, required String to}) {
  final androidRoot = Directory('${root.path}/app/android');
  if (!androidRoot.existsSync()) {
    stdout.writeln('· android/ not present, skipping');
    return;
  }

  for (final path in ['app/build.gradle.kts', 'app/build.gradle']) {
    final file = File('${androidRoot.path}/$path');
    if (file.existsSync()) _replaceInFile(file, from, to);
  }

  final manifest = File('${androidRoot.path}/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    manifest.writeAsStringSync(
      manifest.readAsStringSync().replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$name"'),
    );
    stdout.writeln('· android label → $name');
  }

  _moveJvmPackage(Directory('${androidRoot.path}/app/src/main/kotlin'), from, to);
  _moveJvmPackage(Directory('${androidRoot.path}/app/src/main/java'), from, to);
}

/// Moves `<root>/a/b/c` to `<root>/x/y/z` and rewrites the `package` line.
///
/// Recursive on purpose: `flutter create --project-name app` produces a package
/// like `com.example.flutterbase.app`, so the source file sits one level below
/// the directory the org name alone would suggest. An earlier version of this
/// script listed only the top directory's files, found none, and reported
/// success while moving nothing.
void _moveJvmPackage(Directory sourceRoot, String from, String to) {
  if (!sourceRoot.existsSync()) return;
  // Second line of defence: moving a directory onto itself deletes its files.
  if (from == to) return;

  final fromDir = Directory('${sourceRoot.path}/${from.split('.').join('/')}');
  if (!fromDir.existsSync()) {
    stdout.writeln('· ${_leaf(sourceRoot)} package already renamed, skipping');
    return;
  }

  final toDir = Directory('${sourceRoot.path}/${to.split('.').join('/')}')..createSync(recursive: true);

  var moved = 0;
  for (final entity in fromDir.listSync(recursive: true).whereType<File>()) {
    final relative = entity.path.substring(fromDir.path.length + 1);
    final target = File('${toDir.path}/$relative')..parent.createSync(recursive: true);
    target.writeAsStringSync(entity.readAsStringSync().replaceAll(from, to));
    entity.deleteSync();
    moved++;
  }

  _pruneEmptyDirs(fromDir, stopAt: sourceRoot);
  stdout.writeln('· ${_leaf(sourceRoot)} package $from → $to ($moved file${moved == 1 ? '' : 's'})');
}

/// Deletes now-empty directories upward, never past [stopAt] — otherwise a
/// shared prefix such as `com/` disappears while another package still uses it.
void _pruneEmptyDirs(Directory directory, {required Directory stopAt}) {
  var current = directory;
  while (current.existsSync() &&
      current.path != stopAt.path &&
      current.path.startsWith(stopAt.path) &&
      current.listSync().isEmpty) {
    final parent = current.parent;
    current.deleteSync();
    current = parent;
  }
}

void _renameIos(Directory root, {required String name, required String from, required String to}) {
  final iosRoot = Directory('${root.path}/app/ios');
  if (!iosRoot.existsSync()) {
    stdout.writeln('· ios/ not present, skipping');
    return;
  }

  // Replacing the base identifier also fixes the `.RunnerTests` variants,
  // because they are that identifier plus a suffix.
  final pbxproj = File('${iosRoot.path}/Runner.xcodeproj/project.pbxproj');
  if (pbxproj.existsSync()) _replaceInFile(pbxproj, from, to);

  final plist = File('${iosRoot.path}/Runner/Info.plist');
  if (plist.existsSync()) {
    var contents = plist.readAsStringSync();
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      contents = contents.replaceAllMapped(
        RegExp('<key>$key</key>\\s*<string>[^<]*</string>'),
        (_) => '<key>$key</key>\n\t<string>$name</string>',
      );
    }
    plist.writeAsStringSync(contents);
    stdout.writeln('· ios display name → $name');
  }
}

void _renameWorkspace(Directory root, String name) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return;

  final slug = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  pubspec.writeAsStringSync(
    pubspec.readAsStringSync().replaceFirst(RegExp('^name: .*', multiLine: true), 'name: ${slug}_workspace'),
  );
  stdout.writeln('· workspace → ${slug}_workspace');
}

void _replaceInFile(File file, String from, String to) {
  final contents = file.readAsStringSync();
  if (!contents.contains(from)) return;
  file.writeAsStringSync(contents.replaceAll(from, to));
  stdout.writeln('· ${_leaf(file)}');
}

String _leaf(FileSystemEntity entity) {
  final segments = entity.path.split('/');
  return segments.length < 2 ? entity.path : segments.sublist(segments.length - 2).join('/');
}
