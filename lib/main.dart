import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/app_root.dart';
import 'package:pulse/core/di/app_injection.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/core/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final di = GetIt.instance;
  configureCoreDependencies(di);
  configureTradingDependencies(di);
  configureAppDependencies(di, store: SharedPreferencesKeyValueStore(prefs));
  runApp(AppRoot(di: di));
}
