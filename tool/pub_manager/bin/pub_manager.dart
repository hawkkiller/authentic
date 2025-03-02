import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:prompts/prompts.dart' as prompts;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Main entry point for the pub_manager CLI tool
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

/// Command to handle package publishing workflow
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

    // Phase 1: Discovery and selection
    final packages = _findPackages();
    if (packages.isEmpty) {
      print('No packages found in packages/ directory.');
      return;
    }

    final selectedPackage = _selectPackage(packages);
    final packageInfo = PackageInfo.fromPath(selectedPackage);

    // Phase 2: Version management
    final currentVersion = packageInfo.version;
    print('Current version: $currentVersion');
    final newVersion = _determineNewVersion(currentVersion);

    // Phase 3: Changelog management
    final changelogEntries = _collectChangelogEntries();
    if (changelogEntries.isEmpty) {
      print('No changelog entries provided. Aborting.');
      return;
    }

    // Phase 4: Dependency analysis
    final dependentPackages = _findDependentPackages(packages, packageInfo.name);

    // Phase 5: Summary and confirmation
    _displaySummary(
      packageName: packageInfo.name,
      currentVersion: packageInfo.version,
      newVersion: newVersion,
      changelogEntries: changelogEntries,
      dependentPackages: dependentPackages,
    );

    // Phase 6: Apply changes
    if (!dryRun) {
      if (!_confirmChanges()) {
        print('Aborted by user.');
        return;
      }

      _applyChanges(
        packagePath: selectedPackage,
        packageName: packageInfo.name,
        newVersion: newVersion,
        changelogEntries: changelogEntries,
        dependentPackages: dependentPackages,
      );

      print('\nSuccessfully updated ${packageInfo.name} to version $newVersion');

      // Phase 7: Publish packages
      if (dependentPackages.isNotEmpty) {
        _handlePackagePublishing(selectedPackage, dependentPackages);
      } else {
        _handlePackagePublishing(selectedPackage, []);
      }
    } else {
      print('\nDry run completed. No changes applied.');
    }
  }

  /// Find all packages in the packages/ directory
  List<String> _findPackages() {
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

  /// Interactive package selection
  String _selectPackage(List<String> packages) {
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

  /// Determine the new version based on user input
  String _determineNewVersion(String currentVersion) {
    final versionType = prompts.choose('Select version bump type:', [
      'patch',
      'minor',
      'major',
      'custom',
    ], defaultsTo: 'patch');

    if (versionType == 'custom') {
      return prompts.get('Enter new version:');
    }

    final parts = currentVersion.split('.');
    if (parts.length != 3) {
      print('Invalid version format: $currentVersion. Expected format: x.y.z');
      exit(1);
    }

    int major = int.parse(parts[0]);
    int minor = int.parse(parts[1]);
    int patch = int.parse(parts[2]);

    switch (versionType) {
      case 'patch':
        patch++;
        break;
      case 'minor':
        minor++;
        patch = 0;
        break;
      case 'major':
        major++;
        minor = 0;
        patch = 0;
        break;
    }

    return '$major.$minor.$patch';
  }

  /// Collect changelog entries from user input
  List<String> _collectChangelogEntries() {
    print('\nEnter changelog entries (one per line, empty line to finish):');
    final changelogEntries = <String>[];

    while (true) {
      final entry = stdin.readLineSync()?.trim();
      if (entry == null || entry.isEmpty) break;
      changelogEntries.add('- $entry');
    }

    return changelogEntries;
  }

  /// Find packages that depend on the specified package
  List<String> _findDependentPackages(List<String> allPackages, String packageName) {
    final dependentPackages = <String>[];

    for (final pkg in allPackages) {
      final pubspecFile = File(path.join(pkg, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) continue;

      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as Map;

      // Check regular dependencies
      final deps = yaml['dependencies'] as Map?;
      if (deps != null && deps.containsKey(packageName)) {
        dependentPackages.add(pkg);
        continue;
      }

      // Check dev dependencies
      final devDeps = yaml['dev_dependencies'] as Map?;
      if (devDeps != null && devDeps.containsKey(packageName)) {
        dependentPackages.add(pkg);
      }
    }

    return dependentPackages;
  }

  /// Display summary of changes to be applied
  void _displaySummary({
    required String packageName,
    required String currentVersion,
    required String newVersion,
    required List<String> changelogEntries,
    required List<String> dependentPackages,
  }) {
    print('\n=== Summary ===');
    print('Package to publish: $packageName');
    print('Current version: $currentVersion');
    print('New version: $newVersion');

    print('\nChangelog entries:');
    for (final entry in changelogEntries) {
      print(entry);
    }

    print('\nDependent packages to update:');
    for (final pkg in dependentPackages) {
      print('- ${path.basename(pkg)}');
    }
  }

  /// Confirm changes with user
  bool _confirmChanges() {
    return prompts.getBool('Apply these changes?', defaultsTo: false);
  }

  /// Apply all changes to files
  void _applyChanges({
    required String packagePath,
    required String packageName,
    required String newVersion,
    required List<String> changelogEntries,
    required List<String> dependentPackages,
  }) {
    // Update package version
    _updatePubspecVersion(packagePath, newVersion);

    // Update changelog
    _updateChangelog(packagePath, newVersion, changelogEntries);

    // Update dependencies in dependent packages
    for (final pkg in dependentPackages) {
      _updateDependency(pkg, packageName, newVersion);
    }
  }

  /// Update version in pubspec.yaml
  void _updatePubspecVersion(String packagePath, String newVersion) {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final editor = YamlEditor(content);

    editor.update(['version'], newVersion);
    pubspecFile.writeAsStringSync(editor.toString());
    print('Updated version in pubspec.yaml');
  }

  /// Update or create CHANGELOG.md
  void _updateChangelog(String packagePath, String newVersion, List<String> entries) {
    final changelogFile = File(path.join(packagePath, 'CHANGELOG.md'));
    String content = '';

    if (changelogFile.existsSync()) {
      content = changelogFile.readAsStringSync();
    }

    final timestamp = DateTime.now().toUtc().toString().split(' ')[0]; // YYYY-MM-DD
    final newEntry = '''## $newVersion - $timestamp

${entries.join('\n')}''';

    if (content.isEmpty) {
      // Create new changelog
      content = "# Changelog\n\n$newEntry";
    } else if (content.trim().startsWith('# ')) {
      // Insert after header
      final lines = content.split('\n');
      lines.insert(1, '\n$newEntry');
      content = lines.join('\n');
    } else {
      // Insert at beginning
      content = '$newEntry\n\n$content';
    }

    changelogFile.writeAsStringSync(content);
    print('Updated CHANGELOG.md');
  }

  /// Update dependency version in a package
  void _updateDependency(String packagePath, String dependencyName, String newVersion) {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final editor = YamlEditor(content);
    final packageBaseName = path.basename(packagePath);

    try {
      // Try updating in dependencies section
      editor.update(['dependencies', dependencyName], '^$newVersion');
      print('Updated $dependencyName dependency in $packageBaseName');
    } catch (e) {
      try {
        // Try updating in dev_dependencies section
        editor.update(['dev_dependencies', dependencyName], '^$newVersion');
        print('Updated $dependencyName dev_dependency in $packageBaseName');
      } catch (e) {
        print('Could not update dependency in $packageBaseName');
      }
    }

    pubspecFile.writeAsStringSync(editor.toString());
  }

  /// Handle publishing of packages
  void _handlePackagePublishing(String mainPackagePath, List<String> dependentPackages) {
    final mainPackageName = path.basename(mainPackagePath);

    // Ask to publish the main package
    final publishMain = prompts.getBool(
      '\nPublish the main package ($mainPackageName)?',
      defaultsTo: true,
    );
    if (publishMain) {
      _publishPackage(mainPackagePath);
    }

    if (dependentPackages.isEmpty) return;

    // For dependent packages, let user manually select which ones to publish
    print('\nSelect dependent packages to publish:');
    final selectedPackages = <String>[];

    for (int i = 0; i < dependentPackages.length; i++) {
      final packageName = path.basename(dependentPackages[i]);
      final shouldPublish = prompts.getBool('Publish $packageName?', defaultsTo: false);

      if (shouldPublish) {
        selectedPackages.add(dependentPackages[i]);
      }
    }

    if (selectedPackages.isEmpty) {
      print('No dependent packages selected for publishing.');
      return;
    }

    for (final pkgPath in selectedPackages) {
      _publishPackage(pkgPath);
    }
  }

  /// Publish a single package
  void _publishPackage(String packagePath) {
    final packageName = path.basename(packagePath);
    print('\nPublishing $packageName...');

    try {
      final result = Process.runSync('dart', [
        'pub',
        'publish',
        '--force',
      ], workingDirectory: packagePath);

      if (result.exitCode == 0) {
        print('Successfully published $packageName');
      } else {
        print('Failed to publish $packageName');
        print(result.stderr);
      }
    } catch (e) {
      print('Error publishing $packageName: $e');
    }
  }
}

/// Class to hold package information
class PackageInfo {
  final String name;
  final String version;

  PackageInfo(this.name, this.version);

  /// Create PackageInfo from a package path
  factory PackageInfo.fromPath(String packagePath) {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content) as Map;

    return PackageInfo(yaml['name'] as String, yaml['version'] as String);
  }
}
