import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:prompts/prompts.dart' as prompts;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main(List<String> arguments) {
  final runner = CommandRunner('pub_manager', 'A CLI tool for managing packages in a Dart monorepo')
    ..addCommand(PublishCommand());

  runner.run(arguments).catchError((error) {
    if (error is! UsageException) {
      print('Error: $error');
    }
    exit(64);
  });
}

class PublishCommand extends Command {
  @override
  final name = 'publish';
  @override
  final description = 'Update version, changelog, and dependencies for a package';

  PublishCommand() {
    argParser.addFlag(
      'dry-run',
      abbr: 'd',
      negatable: false,
      help: 'Preview changes without applying them',
    );
  }

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] as bool;

    // 1. Find all packages
    final packages = findPackages();
    if (packages.isEmpty) {
      print('No packages found in packages/ directory.');
      return;
    }

    // 2. Select package to publish
    final selectedPackage = selectPackage(packages);
    final packageInfo = PackageInfo.fromPath(selectedPackage);

    // 3. Select new version
    final currentVersion = packageInfo.version;
    print('Current version: $currentVersion');
    final versionType = prompts.choose('Select version bump type:', [
      'patch',
      'minor',
      'major',
      'custom',
    ], defaultsTo: 'patch');

    String newVersion;
    if (versionType == 'custom') {
      newVersion = prompts.get('Enter new version:');
    } else {
      final parts = currentVersion.split('.');
      if (parts.length != 3) {
        print('Invalid version format: $currentVersion. Expected format: x.y.z');
        return;
      }

      int major = int.parse(parts[0]);
      int minor = int.parse(parts[1]);
      int patch = int.parse(parts[2]);

      if (versionType == 'patch') {
        patch++;
      } else if (versionType == 'minor') {
        minor++;
        patch = 0;
      } else if (versionType == 'major') {
        major++;
        minor = 0;
        patch = 0;
      }

      newVersion = '$major.$minor.$patch';
    }

    // 4. Get changelog entries
    print('\nEnter changelog entries (one per line, empty line to finish):');
    final changelogEntries = <String>[];
    while (true) {
      final entry = stdin.readLineSync()?.trim();
      if (entry == null || entry.isEmpty) break;
      changelogEntries.add('- $entry');
    }

    if (changelogEntries.isEmpty) {
      print('No changelog entries provided. Aborting.');
      return;
    }

    // 5. Find all dependent packages
    final dependentPackages = findDependentPackages(packages, packageInfo.name);

    // 6. Show summary
    print('\n=== Summary ===');
    print('Package to publish: ${packageInfo.name}');
    print('Current version: ${packageInfo.version}');
    print('New version: $newVersion');
    print('\nChangelog entries:');
    for (final entry in changelogEntries) {
      print(entry);
    }
    print('\nDependent packages to update:');
    for (final pkg in dependentPackages) {
      print('- ${path.basename(pkg)}');
    }

    // 7. Confirm and apply changes
    if (!dryRun) {
      final confirm = prompts.getBool('Apply these changes?', defaultsTo: false);
      if (!confirm) {
        print('Aborted by user.');
        return;
      }

      // Update pubspec.yaml version
      updatePubspecVersion(selectedPackage, newVersion);

      // Update CHANGELOG.md
      updateChangelog(selectedPackage, newVersion, changelogEntries);

      // Update dependent packages
      for (final pkg in dependentPackages) {
        updateDependency(pkg, packageInfo.name, newVersion);
      }

      print('\nSuccessfully updated ${packageInfo.name} to version $newVersion');
    } else {
      print('\nDry run completed. No changes applied.');
    }
  }

  List<String> findPackages() {
    final packagesDir = Directory('packages');
    if (!packagesDir.existsSync()) {
      print('Error: packages/ directory not found.');
      exit(1);
    }

    final packages = <String>[];
    for (final entity in packagesDir.listSync()) {
      if (entity is Directory) {
        final pubspecFile = File(path.join(entity.path, 'pubspec.yaml'));
        if (pubspecFile.existsSync()) {
          packages.add(entity.path);
        }
      }
    }

    return packages;
  }

  String selectPackage(List<String> packages) {
    final packageNames = packages.map((p) => path.basename(p)).toList();

    print('\nAvailable packages:');
    for (int i = 0; i < packageNames.length; i++) {
      print('${i + 1}. ${packageNames[i]}');
    }

    final selection = prompts.choose('Select package to publish:', packageNames);

    if (selection == null || selection.isEmpty) {
      print('No package selected. Aborting.');
      exit(1);
    }

    return packages[packageNames.indexOf(selection)];
  }

  List<String> findDependentPackages(List<String> allPackages, String packageName) {
    final dependentPackages = <String>[];

    for (final pkg in allPackages) {
      final pubspecFile = File(path.join(pkg, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) continue;

      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as Map;

      // Check dependencies
      final deps = yaml['dependencies'] as Map?;
      if (deps != null && deps.containsKey(packageName)) {
        dependentPackages.add(pkg);
        continue;
      }

      // Check dev_dependencies
      final devDeps = yaml['dev_dependencies'] as Map?;
      if (devDeps != null && devDeps.containsKey(packageName)) {
        dependentPackages.add(pkg);
      }
    }

    return dependentPackages;
  }

  void updatePubspecVersion(String packagePath, String newVersion) {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final editor = YamlEditor(content);

    editor.update(['version'], newVersion);
    pubspecFile.writeAsStringSync(editor.toString());
    print('Updated version in pubspec.yaml');
  }

  void updateChangelog(String packagePath, String newVersion, List<String> entries) {
    final changelogFile = File(path.join(packagePath, 'CHANGELOG.md'));
    String content = '';

    if (changelogFile.existsSync()) {
      content = changelogFile.readAsStringSync();
    }

    final timestamp = DateTime.now().toUtc().toString().split(' ')[0]; // YYYY-MM-DD
    final newEntry = '''
## $newVersion - $timestamp

${entries.join('\n')}
''';

    if (content.isEmpty) {
      // Create new changelog if it doesn't exist
      content = "# Changelog\n\n$newEntry";
    } else if (content.trim().startsWith('# ')) {
      // If file starts with a header, insert after the first line
      final lines = content.split('\n');
      lines.insert(1, '\n$newEntry');
      content = lines.join('\n');
    } else {
      // Otherwise, insert at the beginning
      content = '$newEntry\n\n$content';
    }

    changelogFile.writeAsStringSync(content);
    print('Updated CHANGELOG.md');
  }

  void updateDependency(String packagePath, String dependencyName, String newVersion) {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final editor = YamlEditor(content);

    // Try updating in dependencies
    try {
      editor.update(['dependencies', dependencyName], '^$newVersion');
      print('Updated $dependencyName dependency in ${path.basename(packagePath)}');
    } catch (e) {
      // Try updating in dev_dependencies
      try {
        editor.update(['dev_dependencies', dependencyName], '^$newVersion');
        print('Updated $dependencyName dev_dependency in ${path.basename(packagePath)}');
      } catch (e) {
        print('Could not update dependency in ${path.basename(packagePath)}');
      }
    }

    pubspecFile.writeAsStringSync(editor.toString());
  }
}

class PackageInfo {
  final String name;
  final String version;

  PackageInfo(this.name, this.version);

  factory PackageInfo.fromPath(String packagePath) {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content) as Map;

    return PackageInfo(yaml['name'] as String, yaml['version'] as String);
  }
}
