import 'dart:io';

import 'standards/checker.dart';

void main(List<String> args) {
  exit(runCli(args, stdout, stderr));
}
