import 'dart:io';
import 'dart:typed_data';

const _sizes = <int>[16, 24, 32, 48, 256];
const _approvedMarkFrame =
    'crop=934:1084:165:83,'
    'pad=1084:1084:75:0:color=black@0';

void main(List<String> arguments) {
  if (arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_openhub_icon.dart [source.png] [output.ico]',
    );
    exitCode = 64;
    return;
  }
  final sourcePath = arguments.isEmpty
      ? 'assets/brand/openhub-route-hub.png'
      : arguments.first;
  final outputPath = arguments.length < 2
      ? 'windows/runner/resources/app_icon.ico'
      : arguments[1];
  final source = File(sourcePath);
  if (!source.existsSync()) {
    throw StateError('OpenHUB icon master was not found: ${source.path}');
  }

  final temporary = Directory.systemTemp.createTempSync('openhub-icon-');
  try {
    final images = <Uint8List>[];
    for (final size in _sizes) {
      final frame = File('${temporary.path}${Platform.pathSeparator}$size.png');
      final result = Process.runSync('ffmpeg', <String>[
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        source.absolute.path,
        '-vf',
        '$_approvedMarkFrame,scale=$size:$size:flags=lanczos',
        '-frames:v',
        '1',
        frame.path,
      ], runInShell: false);
      if (result.exitCode != 0 || !frame.existsSync()) {
        throw StateError(
          'ffmpeg could not render the ${size}px OpenHUB icon frame: ${result.stderr}',
        );
      }
      images.add(frame.readAsBytesSync());
    }

    final writer = _BytesWriter()
      ..u16(0)
      ..u16(1)
      ..u16(images.length);
    var offset = 6 + images.length * 16;
    for (var index = 0; index < images.length; index++) {
      final size = _sizes[index];
      final image = images[index];
      writer
        ..u8(size == 256 ? 0 : size)
        ..u8(size == 256 ? 0 : size)
        ..u8(0)
        ..u8(0)
        ..u16(1)
        ..u16(32)
        ..u32(image.length)
        ..u32(offset);
      offset += image.length;
    }
    for (final image in images) {
      writer.bytes(image);
    }
    final output = File(outputPath)..parent.createSync(recursive: true);
    output.writeAsBytesSync(writer.takeBytes(), flush: true);
    stdout.writeln(
      'Generated ${output.path} from ${source.path} '
      '(${_sizes.join(', ')}px; ${output.lengthSync()} bytes).',
    );
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

class _BytesWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void u8(int value) => _builder.add(<int>[value & 0xff]);

  void u16(int value) => _builder.add(<int>[value & 0xff, (value >> 8) & 0xff]);

  void u32(int value) => _builder.add(<int>[
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);

  void bytes(List<int> value) => _builder.add(value);

  Uint8List takeBytes() => _builder.takeBytes();
}
