import 'dart:convert';
import 'dart:io';

/// Programmatic standards checker (ENF-02). Rules map to
/// docs/CODING_STANDARDS.md. Heuristic by design: see ADR-0006.

const int kMaxFileLines = 800;

const Set<String> _skippedDirs = {
  'build',
  'node_modules',
  'android',
  'ios',
  'Pods',
};

const List<String> _generatedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.config.dart',
  '.mocks.dart',
];

const String _l10nGeneratedDir = 'lib/core/l10n/generated/';

class Violation {
  const Violation({
    required this.file,
    required this.line,
    required this.rule,
    required this.message,
  });

  final String file;
  final int line;
  final String rule;
  final String message;

  @override
  String toString() => '$file:$line $rule $message';
}

bool _isIdentChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Removes comments (and optionally string contents) while preserving every
/// newline so line numbers stay valid.
String sanitizeDart(String src, {bool stripStrings = false}) {
  final out = StringBuffer();
  final n = src.length;
  var i = 0;
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (src.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (src.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          if (src[i] == '\n') out.write('\n');
          i++;
        }
      }
      continue;
    }
    if (c == "'" || c == '"') {
      final isRaw =
          i > 0 && src[i - 1] == 'r' && (i < 2 || !_isIdentChar(src[i - 2]));
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      i += quote.length;
      final content = StringBuffer();
      while (i < n) {
        if (!isRaw && src[i] == r'\' && i + 1 < n) {
          content.write(src.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (src.startsWith(quote, i)) break;
        if (!triple && src[i] == '\n') break;
        content.write(src[i]);
        i++;
      }
      final text = content.toString();
      out.write(quote);
      out.write(stripStrings ? '\n' * '\n'.allMatches(text).length : text);
      if (src.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

final RegExp _moneyWord = RegExp(
  r'\w*(price|qty|quantity|cost|cash|amount|notional|balance|pnl|money)\w*'
  r'|\b(bid|ask|last)\b',
  caseSensitive: false,
);
final RegExp _doubleWord = RegExp(r'\bdouble\b');
final RegExp _castRegex = RegExp(r'\bas\s+[A-Za-z_]');
final RegExp _bangRegex = RegExp(r'\]\s*!(?!=)');
final RegExp _printRegex = RegExp(r'(?<![\w.])(print|debugPrint)\s*\(');
final RegExp _getItRegex = RegExp(r'\bGetIt\b');
final RegExp _flutterImport = RegExp(
  r'''(?:import|export)\s+['"](?:package:flutter|dart:ui)''',
);
final RegExp _apiImport = RegExp(
  r'''(?:import|export)\s+['"]package:pulse_api/''',
);
final RegExp _domainBadImport = RegExp(
  r'''(?:import|export)\s+['"]package:pulse/[^'"]*/(?:data|presentation)/''',
);
final RegExp _presentationBadImport = RegExp(
  r'''(?:import|export)\s+['"]package:pulse/[^'"]*/data/''',
);
final RegExp _relativeImport = RegExp(
  r'''(?:import|export|part)\s+['"]\.\./''',
);
final RegExp _colorsRegex = RegExp(r'\bColors\.|\bColor\s*\(\s*0x');
final RegExp _textLiteral = RegExp(
  r'''\b(?:Text|SelectableText)\s*\(\s*r?(['"])(.*?)\1''',
);
final RegExp _labelLiteral = RegExp(
  r'''\b(?:labelText|hintText|helperText|semanticLabel|tooltip)\s*:\s*r?(['"])(.*?)\1''',
);
final RegExp _hasLetter = RegExp('[A-Za-z؀-ۿ]');
final RegExp _allowRegex = RegExp(r'standards-allow:\s*([A-Z]+-\d+)\s*(.*)$');
final RegExp _generatorDep = RegExp(
  r'^\s+(build_runner|freezed|freezed_annotation|json_serializable|'
  r'json_annotation|injectable|injectable_generator|auto_route_generator|'
  r'riverpod_generator|riverpod_annotation|retrofit_generator|drift_dev|'
  r'hive_generator|mockito)\s*:',
);

String _normalize(String s) {
  final noBom = s.startsWith('﻿') ? s.substring(1) : s;
  return noBom.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

bool _hasLiteralText(RegExpMatch m) {
  final text = m.group(2) ?? '';
  return !text.startsWith(r'$') && _hasLetter.hasMatch(text);
}

/// Checks one Dart source file. [relPath] uses `/` separators.
List<Violation> checkDartSource(String relPath, String source) {
  final text = _normalize(source);
  final path = '/$relPath';
  final isDomain = path.contains('/domain/');
  final isData = path.contains('/data/');
  final isPresentation = path.contains('/presentation/');
  final isStateful = path.contains('/bloc/') || path.contains('/cubit/');
  final isDesignSystem = relPath.startsWith('packages/pulse_design_system/');
  final isCompositionRoot =
      relPath.startsWith('lib/core/di/') ||
      relPath == 'lib/main.dart' ||
      relPath == 'lib/app.dart';

  final original = text.split('\n');
  final code = sanitizeDart(text).split('\n');
  final bare = sanitizeDart(text, stripStrings: true).split('\n');

  final found = <Violation>[];
  void add(int index, String rule, String message) {
    found.add(
      Violation(file: relPath, line: index + 1, rule: rule, message: message),
    );
  }

  final lineCount = text.endsWith('\n') ? original.length - 1 : original.length;
  if (lineCount > kMaxFileLines) {
    add(0, 'SIZE-01', 'file has $lineCount lines (max $kMaxFileLines)');
  }

  for (var i = 0; i < bare.length; i++) {
    final b = bare[i];
    final c = i < code.length ? code[i] : '';
    final trimmed = b.trimLeft();
    final isDirective =
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ') ||
        trimmed.startsWith('part ');

    if (_doubleWord.hasMatch(b) && _moneyWord.hasMatch(b)) {
      add(i, 'MONEY-01', 'double is forbidden for money/price/quantity');
    }
    if (isData && !isDirective) {
      if (_castRegex.hasMatch(b)) {
        add(i, 'CAST-01', "'as' cast on external data is forbidden");
      }
      if (_bangRegex.hasMatch(b)) {
        add(i, 'BANG-01', "'!' on map access of external data is forbidden");
      }
    }
    if (_printRegex.hasMatch(b)) {
      add(i, 'PRINT-01', 'print/debugPrint is forbidden; use AppLogger');
    }
    if ((isDomain || isData || isStateful) && _getItRegex.hasMatch(b)) {
      add(i, 'GETIT-01', 'GetIt only in the composition root');
    }
    if (isDomain && _flutterImport.hasMatch(c)) {
      add(i, 'LAYER-01', 'domain must not import Flutter');
    }
    if (!isData && !isCompositionRoot && _apiImport.hasMatch(c)) {
      add(i, 'LAYER-02', 'package:pulse_api only in data/ or composition root');
    }
    if (isDomain && _domainBadImport.hasMatch(c)) {
      add(i, 'LAYER-03', 'domain must not import data/presentation');
    }
    if (isPresentation && _presentationBadImport.hasMatch(c)) {
      add(i, 'LAYER-03', 'presentation must not import data');
    }
    if (_relativeImport.hasMatch(c)) {
      add(i, 'IMPORT-01', "use package: imports, not '../'");
    }
    if (path.contains('/features/') && !isDesignSystem) {
      if (_colorsRegex.hasMatch(b)) {
        add(i, 'COLOR-01', 'use design-system tokens, not raw colors');
      }
    }
    if (isPresentation) {
      final text1 = _textLiteral.firstMatch(c);
      final text2 = _labelLiteral.firstMatch(c);
      if ((text1 != null && _hasLiteralText(text1)) ||
          (text2 != null && _hasLiteralText(text2))) {
        add(i, 'STR-01', 'user-facing string literal; use AppLocalizations');
      }
    }
  }

  return _applyAllowList(relPath, original, found);
}

List<Violation> _applyAllowList(
  String relPath,
  List<String> original,
  List<Violation> found,
) {
  final allowed = <String>{};
  final extra = <Violation>[];
  for (var i = 0; i < original.length; i++) {
    final m = _allowRegex.firstMatch(original[i]);
    if (m == null) continue;
    final rule = m.group(1) ?? '';
    final reason = (m.group(2) ?? '').trim();
    if (reason.length >= 3) {
      allowed.add('${i + 1}:$rule');
    } else {
      extra.add(
        Violation(
          file: relPath,
          line: i + 1,
          rule: 'ALLOW-01',
          message: 'standards-allow for $rule needs a written reason',
        ),
      );
    }
  }
  return [
    ...found.where((v) => !allowed.contains('${v.line}:${v.rule}')),
    ...extra,
  ];
}

/// Checks a pubspec.yaml for code-generation packages (DEP-01).
List<Violation> checkPubspec(String relPath, String content) {
  final lines = _normalize(content).split('\n');
  final out = <Violation>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('#')) continue;
    if (_generatorDep.hasMatch(line)) {
      out.add(
        Violation(
          file: relPath,
          line: i + 1,
          rule: 'DEP-01',
          message: 'code generators are forbidden: ${line.trim()}',
        ),
      );
    }
  }
  return out;
}

bool _isUnderLib(String rel) =>
    rel.startsWith('lib/') || RegExp(r'^packages/[^/]+/lib/').hasMatch(rel);

bool _isPubspec(String rel) =>
    rel == 'pubspec.yaml' ||
    RegExp(r'^packages/[^/]+/pubspec\.yaml$').hasMatch(rel);

void _walk(Directory dir, String rel, void Function(File, String) visit) {
  List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } on FileSystemException {
    return;
  }
  for (final e in entries) {
    final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final childRel = rel.isEmpty ? name : '$rel/$name';
    if (e is Link) continue;
    if (e is Directory) {
      if (name.startsWith('.') || _skippedDirs.contains(name)) continue;
      _walk(e, childRel, visit);
    } else if (e is File) {
      visit(e, childRel);
    }
  }
}

/// Scans a project root and returns violations sorted by file then line.
List<Violation> checkProject(Directory root) {
  final out = <Violation>[];
  _walk(root, '', (file, rel) {
    if (_isPubspec(rel)) {
      out.addAll(checkPubspec(rel, _read(file)));
      return;
    }
    if (!rel.endsWith('.dart') || !_isUnderLib(rel)) return;
    if (rel.startsWith(_l10nGeneratedDir)) return;
    if (_generatedSuffixes.any(rel.endsWith)) {
      out.add(
        Violation(
          file: rel,
          line: 1,
          rule: 'GEN-01',
          message: 'generated files are forbidden',
        ),
      );
      return;
    }
    out.addAll(checkDartSource(rel, _read(file)));
  });
  out.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });
  return out;
}

String _read(File f) => utf8.decode(f.readAsBytesSync(), allowMalformed: true);

/// CLI: `check_standards [root]`. Exit 0 clean, 1 violations, 2 usage error.
int runCli(List<String> args, StringSink out, StringSink err) {
  if (args.length > 1) {
    err.writeln('usage: check_standards [project_root]');
    return 2;
  }
  final root = args.isEmpty ? Directory.current : Directory(args.first);
  if (!root.existsSync()) {
    err.writeln('error: root does not exist: ${root.path}');
    return 2;
  }
  final violations = checkProject(root);
  if (violations.isEmpty) {
    out.writeln('OK: no standards violations');
    return 0;
  }
  violations.forEach(out.writeln);
  out.writeln('FAILED: ${violations.length} violation(s)');
  return 1;
}
