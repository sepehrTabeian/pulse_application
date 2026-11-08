import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../standards/checker.dart';

List<String> _rules(List<Violation> v) => v.map((e) => e.rule).toList();

List<Violation> _src(String path, String source) =>
    checkDartSource(path, source);

void main() {
  group('sanitizeDart', () {
    test('removes line comments but keeps line count', () {
      final out = sanitizeDart('a // double price\nb\n', stripStrings: true);

      expect(out, 'a \nb\n');
    });

    test('removes nested block comments and keeps newlines', () {
      final out = sanitizeDart('a /* x /* y\n */ z\n */ b', stripStrings: true);

      expect(out.split('\n').length, 3);
      expect(out.contains('x'), isFalse);
      expect(out.contains('z'), isFalse);
      expect(out.endsWith(' b'), isTrue);
    });

    test('does not treat // inside a string as comment', () {
      final out = sanitizeDart("var u = 'http://x.y'; var d = 1;");

      expect(out.contains('var d = 1;'), isTrue);
    });

    test('strips string contents when asked', () {
      final out = sanitizeDart("var s = 'double price';", stripStrings: true);

      expect(out, "var s = '';");
    });

    test('keeps string contents by default', () {
      final out = sanitizeDart("var s = 'double price';");

      expect(out.contains('double price'), isTrue);
    });

    test('handles escaped quote inside string', () {
      final out = sanitizeDart(
        r"var s = 'it\'s double'; var t = 1;",
        stripStrings: true,
      );

      expect(out.contains('double'), isFalse);
      expect(out.contains('var t = 1;'), isTrue);
    });

    test('handles raw strings without escapes', () {
      final out = sanitizeDart(
        r"var s = r'a\'; var t = 1;",
        stripStrings: true,
      );

      expect(out.contains('var t = 1;'), isTrue);
    });

    test('handles triple quoted multi-line strings keeping newlines', () {
      final out = sanitizeDart(
        "var s = '''a\nprint(1)\nb'''; var t = 1;",
        stripStrings: true,
      );

      expect(out.split('\n').length, 3);
      expect(out.contains('print'), isFalse);
      expect(out.contains('var t = 1;'), isTrue);
    });

    test('unterminated string does not swallow following lines', () {
      final out = sanitizeDart(
        "var s = 'oops\nvar d = 1;\n",
        stripStrings: true,
      );

      expect(out.contains('var d = 1;'), isTrue);
    });

    test('empty input returns empty output', () {
      expect(sanitizeDart(''), '');
    });
  });

  group('MONEY-01 (double for money)', () {
    test('flags double used for price', () {
      final v = _src('lib/features/a/domain/x.dart', 'final double price = 1;');

      expect(_rules(v), ['MONEY-01']);
    });

    test('flags double.parse on quantity', () {
      final v = _src(
        'lib/features/a/data/x.dart',
        'final q = double.parse(quantity);',
      );

      expect(_rules(v), contains('MONEY-01'));
    });

    test('flags bid and ask as standalone identifiers', () {
      expect(
        _rules(_src('lib/a/domain/x.dart', 'double bid = 0;')),
        contains('MONEY-01'),
      );
      expect(
        _rules(_src('lib/a/domain/x.dart', 'double ask = 0;')),
        contains('MONEY-01'),
      );
    });

    test('does not flag double for non-money names', () {
      final v = _src('lib/a/presentation/x.dart', 'final double opacity = 1;');

      expect(v, isEmpty);
    });

    test('does not flag identifiers merely containing double', () {
      final v = _src('lib/a/presentation/x.dart', 'void doubleTapPrice() {}');

      expect(v, isEmpty);
    });

    test('does not flag words containing ask or last as substrings', () {
      final v = _src('lib/a/domain/x.dart', 'final double taskScale = 1;');

      expect(v, isEmpty);
    });

    test('ignores matches inside comments and strings', () {
      final v = _src(
        'lib/a/domain/x.dart',
        "// double price\nconst s = 'double price';\n",
      );

      expect(v, isEmpty);
    });

    test('reports correct line number', () {
      final v = _src('lib/a/domain/x.dart', 'a\nb\ndouble cash = 1;\n');

      expect(v.single.line, 3);
    });
  });

  group('CAST-01 / BANG-01 (unsafe external data access)', () {
    test('flags as-cast in data layer', () {
      final v = _src(
        'lib/features/a/data/m.dart',
        "final s = json['k'] as String;",
      );

      expect(_rules(v), ['CAST-01']);
    });

    test('flags null-assert on map access in data layer', () {
      final v = _src('lib/features/a/data/m.dart', "final s = json['k']!;");

      expect(_rules(v), ['BANG-01']);
    });

    test('does not flag import-as alias', () {
      final v = _src(
        'lib/features/a/data/m.dart',
        "import 'dart:convert' as convert;",
      );

      expect(v, isEmpty);
    });

    test('does not flag casts outside data layer', () {
      final v = _src(
        'lib/features/a/presentation/m.dart',
        'final s = x as int;',
      );

      expect(v, isEmpty);
    });

    test('does not flag the word as in comments or strings', () {
      final v = _src(
        'lib/features/a/data/m.dart',
        "// x as String\nconst t = 'x as String';",
      );

      expect(v, isEmpty);
    });
  });

  group('PRINT-01', () {
    test('flags print and debugPrint', () {
      final v = _src('lib/a/x.dart', 'print(1);\ndebugPrint("x");');

      expect(_rules(v), ['PRINT-01', 'PRINT-01']);
    });

    test('does not flag method named print on an object or longer names', () {
      final v = _src(
        'lib/a/x.dart',
        'p.print(1);\nsprint(2);\nfingerprint(3);',
      );

      expect(v, isEmpty);
    });
  });

  group('GETIT-01', () {
    test('flags GetIt in domain, data and bloc paths', () {
      for (final p in [
        'lib/features/a/domain/x.dart',
        'lib/features/a/data/x.dart',
        'lib/features/a/presentation/bloc/x.dart',
      ]) {
        expect(
          _rules(_src(p, 'final x = GetIt.I<Foo>();')),
          contains('GETIT-01'),
          reason: p,
        );
      }
    });

    test('allows GetIt in composition root', () {
      final v = _src('lib/core/di/injection.dart', 'final g = GetIt.instance;');

      expect(v, isEmpty);
    });
  });

  group('LAYER-* (dependency rule)', () {
    test('domain must not import flutter', () {
      final v = _src(
        'lib/features/a/domain/x.dart',
        "import 'package:flutter/material.dart';",
      );

      expect(_rules(v), ['LAYER-01']);
    });

    test('domain must not import pulse_api', () {
      final v = _src(
        'lib/features/a/domain/x.dart',
        "import 'package:pulse_api/pulse_api.dart';",
      );

      expect(_rules(v), contains('LAYER-02'));
    });

    test('pulse_api only allowed in data and composition root', () {
      expect(
        _src(
          'lib/features/a/data/x.dart',
          "import 'package:pulse_api/pulse_api.dart';",
        ),
        isEmpty,
      );
      expect(
        _src(
          'lib/core/di/injection.dart',
          "import 'package:pulse_api/pulse_api.dart';",
        ),
        isEmpty,
      );
      expect(
        _rules(
          _src(
            'lib/features/a/presentation/x.dart',
            "import 'package:pulse_api/pulse_api.dart';",
          ),
        ),
        ['LAYER-02'],
      );
    });

    test('domain must not import data or presentation', () {
      final v = _src(
        'lib/features/a/domain/x.dart',
        "import 'package:pulse/features/a/data/m.dart';\n"
            "import 'package:pulse/features/a/presentation/p.dart';",
      );

      expect(_rules(v), ['LAYER-03', 'LAYER-03']);
    });

    test('presentation must not import data', () {
      final v = _src(
        'lib/features/a/presentation/x.dart',
        "import 'package:pulse/features/a/data/m.dart';",
      );

      expect(_rules(v), ['LAYER-03']);
    });

    test('commented-out import is ignored', () {
      final v = _src(
        'lib/features/a/domain/x.dart',
        "// import 'package:flutter/material.dart';",
      );

      expect(v, isEmpty);
    });
  });

  group('IMPORT-01', () {
    test('flags ../ relative imports', () {
      final v = _src('lib/a/x.dart', "import '../b/y.dart';");

      expect(_rules(v), ['IMPORT-01']);
    });

    test('allows package imports', () {
      expect(_src('lib/a/x.dart', "import 'package:pulse/b/y.dart';"), isEmpty);
    });
  });

  group('COLOR-01 / STR-01 (design tokens and l10n in features)', () {
    test('flags Colors.* and Color(0x..) in features', () {
      final v = _src(
        'lib/features/a/presentation/w.dart',
        'final c = Colors.red;\nfinal d = Color(0xFF000000);',
      );

      expect(_rules(v), ['COLOR-01', 'COLOR-01']);
    });

    test('does not flag Colors in the design system package', () {
      final v = _src(
        'packages/pulse_design_system/lib/src/x.dart',
        'final c = Colors.red;',
      );

      expect(v, isEmpty);
    });

    test('flags literal user-facing text in presentation', () {
      final v = _src(
        'lib/features/a/presentation/w.dart',
        "Widget a() => Text('Buy');",
      );

      expect(_rules(v), ['STR-01']);
    });

    test('flags persian literal text too', () {
      final v = _src(
        'lib/features/a/presentation/w.dart',
        "Widget a() => const Text('خرید');",
      );

      expect(_rules(v), ['STR-01']);
    });

    test('does not flag localized or non-letter text', () {
      final v = _src(
        'lib/features/a/presentation/w.dart',
        "Widget a() => Text(l10n.buy);\nWidget b() => const Text('-');\n"
            "Widget c() => Text('\$x');",
      );

      expect(v, isEmpty);
    });
  });

  group('SIZE-01', () {
    test('flags files over 800 lines', () {
      final v = _src('lib/a/x.dart', List.filled(801, '// c').join('\n'));

      expect(_rules(v), ['SIZE-01']);
    });

    test('accepts exactly 800 lines', () {
      final v = _src('lib/a/x.dart', List.filled(800, '// c').join('\n'));

      expect(v, isEmpty);
    });
  });

  group('allow mechanism', () {
    test('suppresses a violation when reason is given', () {
      final v = _src(
        'lib/a/x.dart',
        'print(1); // standards-allow: PRINT-01 bootstrap logging only',
      );

      expect(v, isEmpty);
    });

    test('allow without reason is itself a violation', () {
      final v = _src('lib/a/x.dart', 'print(1); // standards-allow: PRINT-01');

      expect(_rules(v), containsAll(['PRINT-01', 'ALLOW-01']));
    });

    test('allow for another rule does not suppress', () {
      final v = _src(
        'lib/a/x.dart',
        'print(1); // standards-allow: MONEY-01 not relevant here',
      );

      expect(_rules(v), ['PRINT-01']);
    });
  });

  group('checkPubspec (DEP-01)', () {
    test('flags generator packages in dependencies', () {
      final v = checkPubspec('pubspec.yaml', '''
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.0.0
  json_serializable: ^6.0.0
''');

      expect(_rules(v), ['DEP-01', 'DEP-01', 'DEP-01']);
    });

    test('ignores commented generator lines', () {
      final v = checkPubspec('pubspec.yaml', '  # build_runner: ^2.4.0\n');

      expect(v, isEmpty);
    });

    test('does not flag packages that merely contain the name', () {
      final v = checkPubspec('pubspec.yaml', '  my_freezed_helper: ^1.0.0\n');

      expect(v, isEmpty);
    });

    test('handles CRLF line endings', () {
      final v = checkPubspec('pubspec.yaml', '  build_runner: ^2.4.0\r\n');

      expect(_rules(v), ['DEP-01']);
    });
  });

  group('checkProject (filesystem)', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('standards test é ');
    });

    tearDown(() => root.deleteSync(recursive: true));

    void write(String rel, String content) {
      final f = File('${root.path}/$rel');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(content);
    }

    test('empty project has no violations', () {
      expect(checkProject(root), isEmpty);
    });

    test('project without lib directory has no violations', () {
      write('pubspec.yaml', 'name: x\n');

      expect(checkProject(root), isEmpty);
    });

    test('flags generated files but not the l10n output directory', () {
      write('lib/a/model.g.dart', '// gen');
      write('lib/core/l10n/generated/app_localizations.g.dart', '// gen');

      final v = checkProject(root);

      expect(_rules(v), ['GEN-01']);
      expect(v.single.file, 'lib/a/model.g.dart');
    });

    test('scans nested package lib directories', () {
      write('packages/ds/lib/x.dart', 'print(1);');

      expect(_rules(checkProject(root)), ['PRINT-01']);
    });

    test('works with spaces and unicode in the root path', () {
      write('lib/features/a/domain/x.dart', 'double price = 1;');

      expect(_rules(checkProject(root)), ['MONEY-01']);
    });

    test('CRLF files keep correct line numbers', () {
      write('lib/a/x.dart', 'a\r\nb\r\nprint(1);\r\n');

      expect(checkProject(root).single.line, 3);
    });

    test('non-dart files and build directories are ignored', () {
      write('lib/a/readme.md', 'print(1);');
      write('build/x.dart', 'print(1);');
      write('.dart_tool/x.dart', 'print(1);');

      expect(checkProject(root), isEmpty);
    });

    test('malformed utf8 does not crash the checker', () {
      final f = File('${root.path}/lib/a/bin.dart');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync([0xff, 0xfe, 0x00, 0x70, 0x72]);

      expect(() => checkProject(root), returnsNormally);
    });

    test('results are sorted by file then line', () {
      write('lib/b/x.dart', 'print(1);');
      write('lib/a/x.dart', 'a\nprint(1);\nprint(2);');

      final v = checkProject(root);

      expect(v.map((e) => '${e.file}:${e.line}').toList(), [
        'lib/a/x.dart:2',
        'lib/a/x.dart:3',
        'lib/b/x.dart:1',
      ]);
    });
  });

  group('runCli', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('standards_cli'));
    tearDown(() => root.deleteSync(recursive: true));

    test('returns 0 and prints OK on a clean project', () {
      final out = StringBuffer();

      final code = runCli([root.path], out, StringBuffer());

      expect(code, 0);
      expect(out.toString(), contains('OK'));
    });

    test('returns 1 and prints file:line RULE message on violations', () {
      File('${root.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('print(1);');
      final out = StringBuffer();

      final code = runCli([root.path], out, StringBuffer());

      expect(code, 1);
      expect(out.toString(), matches(RegExp(r'lib/a\.dart:1 PRINT-01 .+')));
    });

    test('returns 2 when root does not exist', () {
      final err = StringBuffer();

      final code = runCli(['${root.path}/missing'], StringBuffer(), err);

      expect(code, 2);
      expect(err.toString(), isNotEmpty);
    });

    test('defaults to current directory when no argument is passed', () {
      expect(runCli([], StringBuffer(), StringBuffer()), anyOf(0, 1));
    });

    test('returns 2 on too many arguments', () {
      expect(runCli(['a', 'b'], StringBuffer(), StringBuffer()), 2);
    });
  });
}
