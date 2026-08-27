import 'dart:async';

import 'package:flutter/material.dart';

import 'core/runtime/runtime_config.dart';
import 'core/runtime/windows_platform_bridge.dart';
import 'core/performance_probe.dart';
import 'state/app_controller.dart';
import 'ui/app_theme.dart';
import 'ui/native_workspace.dart';

class OpenHubApp extends StatefulWidget {
  const OpenHubApp({
    required this.config,
    required this.configurationError,
    this.performanceProbe,
    super.key,
  });

  final RuntimeConfig? config;
  final Object? configurationError;
  final NativePerformanceProbe? performanceProbe;

  @override
  State<OpenHubApp> createState() => _OpenHubAppState();
}

class _OpenHubAppState extends State<OpenHubApp> with WidgetsBindingObserver {
  static const WindowsPlatformBridge _platformBridge = WindowsPlatformBridge();
  AppController? _controller;
  bool _nativeCloseInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBridge.installCloseHandler(_handleNativeCloseRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.performanceProbe?.markShellVisible();
      if (widget.config == null) {
        widget.performanceProbe?.markRuntimeActionable('configuration-error');
      }
    });
    final config = widget.config;
    if (config != null) {
      _controller = AppController(
        config: config,
        performanceProbe: widget.performanceProbe,
      );
      unawaited(_controller!.initialize());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_controller?.shutdown());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _platformBridge.clearCloseHandler();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleNativeCloseRequest() async {
    if (_nativeCloseInProgress) {
      return;
    }
    _nativeCloseInProgress = true;
    try {
      await _controller?.shutdown();
    } finally {
      await _platformBridge.allowWindowClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenHUB',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _controller == null
          ? ConfigurationFailureScreen(error: widget.configurationError)
          : NativeWorkspace(controller: _controller!),
    );
  }
}

class ConfigurationFailureScreen extends StatelessWidget {
  const ConfigurationFailureScreen({required this.error, super.key});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppPalette.red.withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.gpp_bad_outlined,
                      color: AppPalette.red,
                      size: 34,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Native startup was blocked',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'The local endpoint or data path did not pass the safety checks. No backend was started and no data was changed.',
                    ),
                    const SizedBox(height: 18),
                    SelectableText(
                      error?.toString() ?? 'Unknown configuration error',
                      style: const TextStyle(color: AppPalette.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
