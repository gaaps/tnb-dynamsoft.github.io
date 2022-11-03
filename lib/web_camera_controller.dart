import 'dart:async';
import 'dart:html' as html;
import 'dart_ui/dart_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum WebCameraFacing { front, back }

enum WebCameraOutputFormat { png, bytes }

class WebCameraController {
  final String _webviewId =
      'WebCamera-${DateTime.now().millisecondsSinceEpoch}';
  String get webviewId => _webviewId;

  Size? _webviewVideoSize;
  Size? get webviewVideoSize => _webviewVideoSize;

  // The video stream. Will be initialized later to see which camera needs to be used.
  html.MediaStream? _localStream;
  final html.VideoElement _videoElement = html.VideoElement();

  final html.DivElement _vidDiv = html.DivElement();

  // Timer used to capture frames to be analyzed
  Timer? _frameInterval;

  int get height => 720;

  int get width => 1280;

  //
  // Lifecycle
  //

  Future<void> init(
      {required WebCameraFacing facing,
        required bool streamImages,
        required WebCameraOutputFormat format,
        Function(List<int>?)? onImage}) async {
    _vidDiv.children = [_videoElement];
    ui.platformViewRegistry.registerViewFactory(
      _webviewId,
          (int id) => _vidDiv
        ..style.width = '100%'
        ..style.height = '100%',
    );
    // Check if stream is running
    if (_localStream != null) {
      _webviewVideoSize = Size(
        _videoElement.videoWidth.toDouble(),
        _videoElement.videoHeight.toDouble(),
      );
    }
    try {
      final Map? capabilities =
      html.window.navigator.mediaDevices?.getSupportedConstraints();
      print("Capabilities : $capabilities");
      Map<String, dynamic> constraints = {
        'video': {
          "focusMode": {"ideal": "continuous"},
          "width": {"ideal": width},
          "height": {"ideal": height},
          "frameRate": {"ideal": 20, "max": 20},
          "zoom": {"ideal": 1.2}
        },
      };
      if (capabilities?['facingMode'] as bool? ?? false) {
        constraints["video"]["facingMode"] = {
          "ideal": facing == WebCameraFacing.front ? 'user' : 'environment',
        };
      }
      print("Applied constraints : $constraints");
      _localStream =
      await html.window.navigator.mediaDevices?.getUserMedia(constraints);
      _videoElement.srcObject = _localStream;
      // required to tell iOS safari we don't want fullscreen
      _videoElement.setAttribute('playsinline', 'true');
      await _videoElement.play();
      _webviewVideoSize = Size(
        _videoElement.videoWidth.toDouble(),
        _videoElement.videoHeight.toDouble(),
      );
      _frameInterval = Timer.periodic(const Duration(milliseconds: 800), (timer) {
        takePicture(format).then((value) {
          if (onImage != null) onImage(value);
        });
      });
    } catch (e) {
      throw PlatformException(code: 'WebCameraController', message: '$e');
    }
  }

  void dispose() {
    try {
      // Stop the camera stream
      _localStream?.getTracks().forEach((track) {
        if (track.readyState == 'live') {
          track.stop();
        }
      });
    } catch (e) {
      debugPrint('Failed to stop stream: $e');
    }
    _frameInterval?.cancel();
    _videoElement.srcObject = null;
    _localStream = null;
  }

  //
  // Action
  //

  Future<List<int>> takePicture(WebCameraOutputFormat format) async {
    final canvas = html.CanvasElement(
        width: _videoElement.videoWidth, height: _videoElement.videoHeight);
    canvas.context2D.drawImage(_videoElement, 0, 0);

    if (format == WebCameraOutputFormat.bytes) {
      final html.ImageData data = canvas.context2D.getImageData(
          0, 0, _videoElement.videoWidth, _videoElement.videoHeight);
      print(data.data.sublist(0, 20));
      return Uint8List.fromList(data.data.toList());
    }

    html.Blob blob = await canvas.toBlob();
    html.FileReader reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;
    return (reader.result as Uint8List).toList();
  }
}
