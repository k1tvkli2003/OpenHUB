import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/core/performance_probe.dart';
import 'src/core/runtime/runtime_config.dart';

void main(List<String> arguments) {
  final performanceProbe = NativePerformanceProbe.fromEnvironment();
  WidgetsFlutterBinding.ensureInitialized();

  RuntimeConfig? config;
  Object? configurationError;
  try {
    config = RuntimeConfig.fromEnvironment(arguments: arguments);
  } on Object catch (error) {
    configurationError = error;
  }

  runApp(
    OpenHubApp(
      config: config,
      configurationError: configurationError,
      performanceProbe: performanceProbe,
    ),
  );
}
