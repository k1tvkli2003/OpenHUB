import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'authenticated writable startup automatically refreshes account usage',
    () {
      final nativeRoot =
          path.basename(Directory.current.path) == 'native_windows'
          ? Directory.current.path
          : path.join(Directory.current.path, 'native_windows');
      final controllerSource = File(
        path.join(nativeRoot, 'lib', 'src', 'state', 'app_controller.dart'),
      ).readAsStringSync();

      expect(
        controllerSource,
        contains(
          'if (canWrite && performanceProbe?.syntheticAccountRows == null)',
        ),
      );
      expect(controllerSource, contains('unawaited(refreshAccountUsage());'));
      expect(
        controllerSource.indexOf('unawaited(refreshAccountUsage());'),
        greaterThan(controllerSource.indexOf('await refreshCore();')),
      );
    },
  );
}
